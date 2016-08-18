/*
* Licensed to the Apache Software Foundation (ASF) under one
* or more contributor license agreements. See the NOTICE file
* distributed with this work for additional information
* regarding copyright ownership. The ASF licenses this file
* to you under the Apache License, Version 2.0 (the
* "License"); you may not use this file except in compliance
* with the License. You may obtain a copy of the License at
*
*   http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing,
* software distributed under the License is distributed on an
* "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
* KIND, either express or implied. See the License for the
* specific language governing permissions and limitations
* under the License.
*/

import Foundation

public class THTTPTransport: TTransport {
  public var url: URL {
    didSet {
      setupRequest()
    }
  }
  var requestDat: Data?
  var request: URLRequest?
  var requestData = Data()
  var responseData = Data()
  var responseDataOffset: Int = 0
  var userAgent: String?
  var timeout: TimeInterval = 0
  var token: String?
  
  public convenience init(url: URL) {
    self.init(url: url, userAgent: nil, timeout: 0)
  }

  public init(url: URL, userAgent: String?, timeout: TimeInterval, authToken: String? = nil) {
    self.url = url
    self.userAgent = userAgent
    self.timeout = timeout
    token = authToken

    setupRequest()
  }

  func setupRequest() {
    // set up our request object that we'll use for each request
    request = URLRequest(url: url)
    request?.httpMethod = "POST"
    request?.setValue("application/x-thrift", forHTTPHeaderField: "Content-Type")
    request?.setValue("application/x-thrift", forHTTPHeaderField: "Accept")

    request?.setValue(userAgent ?? "Thrift/Cocoa", forHTTPHeaderField: "User-Agent")
    if let token = token {
      request?.setValue("Token=\"\(token)\"", forHTTPHeaderField: "Authorization")
    }
    
    request?.cachePolicy = .reloadIgnoringCacheData
    
    if timeout != 0 {
      request?.timeoutInterval = timeout
    }
  }

//  public func readAll(_ buff: UnsafeMutablePointer<UInt8>, offset: UInt32, length: UInt32) throws {
  public func readAll(size: Int) throws -> Data {
    let read = try self.read(size: size)
    if read.count != size {
      throw TTransportError(error:.endOfFile)
    }
    return read
  }
  
  public func read(size: Int) throws -> Data {
    let avail = responseData.count - responseDataOffset
    let (start, stop) = (responseDataOffset, responseDataOffset + min(size, avail))
    let read = responseData.subdata(in: start..<stop)
    return read
  }
  
  public func write(data: Data) throws {
    requestData.append(data)
  }
  
  public func flush() throws {
    
    request?.httpBody = requestData
    
    
    // reset response data offset and request data
    responseDataOffset = 0
    requestData = Data()

    // make the HTTP Request
    var response: URLResponse?
    URLSession.shared.dataTask(with: request!)
    
    responseData = try NSURLConnection.sendSynchronousRequest(request!, returning: &response)
    
    if let httpResponse = response as? HTTPURLResponse {
      if httpResponse.statusCode != 200 {
        if httpResponse.statusCode == 401 {
          throw THTTPTransportError(error: .authentication)
        } else {
          throw THTTPTransportError(error: .invalidStatus(statusCode: httpResponse.statusCode))
        }
      }
    } else {
      throw THTTPTransportError(error: .invalidResponse)
    }
  }
}

