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

// Temporary until Foundation includes these as proper keys
// FIXME: Remove when ready
extension CFStreamPropertyKey {
  static let shouldCloseNativeSocket  = CFStreamPropertyKey(kCFStreamPropertyShouldCloseNativeSocket)
  // Exists as Stream.PropertyKey.socketSecuritylevelKey but doesn't work with CFReadStreamSetProperty
  static let socketSecurityLevel      = CFStreamPropertyKey(kCFStreamPropertySocketSecurityLevel)
  static let SSLSettings              = CFStreamPropertyKey(kCFStreamPropertySSLSettings)
}

extension Stream.PropertyKey {
  static let SSLPeerTrust = Stream.PropertyKey(kCFStreamPropertySSLPeerTrust as String)
}

public class TSocketTransport: TStreamTransport {
  public init?(hostname: String, port: Int) {
    
    var inputStream: InputStream
    var outputStream: OutputStream
    
    var readStream:  Unmanaged<CFReadStream>?
    var writeStream:  Unmanaged<CFWriteStream>?
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                       hostname as CFString!,
                                       UInt32(port),
                                       &readStream,
                                       &writeStream)
    
    if let readStream = readStream?.takeRetainedValue(),
       let writeStream = writeStream?.takeRetainedValue() {
      CFReadStreamSetProperty(readStream, .shouldCloseNativeSocket, kCFBooleanTrue)
      CFWriteStreamSetProperty(writeStream, .shouldCloseNativeSocket, kCFBooleanTrue)
      
      inputStream = readStream
      inputStream.schedule(in: .current, forMode: .defaultRunLoopMode)
      inputStream.open()
      
      outputStream = writeStream
      outputStream.schedule(in: .current, forMode: .defaultRunLoopMode)
      outputStream.open()

    } else {
      
      if readStream != nil {
        readStream?.release()
      }
      if writeStream != nil {
        writeStream?.release()
      }
      super.init(inputStream: nil, outputStream: nil)
      return nil
    }
    
    super.init(inputStream: inputStream, outputStream: outputStream)
    
    self.input?.delegate = self
    self.output?.delegate = self
  }
}

extension TSocketTransport: StreamDelegate { }
