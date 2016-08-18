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
import Darwin

public let TSocketServerClientConnectionFinished = "TSocketServerClientConnectionFinished"
public let TSocketServerProcessorKey = "TSocketServerProcessor"
public let TSocketServerTransportKey = "TSocketServerTransport"

public class TSocketServer {
  var inputProtocolFactory: TProtocolFactory
  var outputProtocolFactory: TProtocolFactory
  var processorFactory: TProcessorFactory
  var socketFileHandle: FileHandle!
  var processingQueue: DispatchQueue

  public init?(port: Int, protocolFactory: TProtocolFactory, processorFactory: TProcessorFactory) {
    self.inputProtocolFactory = protocolFactory
    self.outputProtocolFactory = protocolFactory
    self.processorFactory = processorFactory
    
    processingQueue = DispatchQueue(label: "TSocketServer.processing",
                                    qos: .background,
                                    attributes: .concurrent)
    
    // create a socket
    var fd: Int32 = -1
    let sock = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, 0, nil, nil)
    if sock != nil {
      CFSocketSetSocketFlags(sock, CFSocketGetSocketFlags(sock) & ~kCFSocketCloseOnInvalidate)
      
      fd = CFSocketGetNative(sock)
      var yes = 1
      setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, UInt32(MemoryLayout<Int>.size))
      
      var addr = sockaddr_in()
      
      memset(&addr, 0, MemoryLayout<sockaddr_in>.size)
      addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
      addr.sin_family = UInt8(AF_INET)
      addr.sin_port = UInt16(port).bigEndian
      addr.sin_addr.s_addr = UInt32(0x00000000).bigEndian // INADDR_ANY = (u_int32_t)0x00000000 ----- <netinet/in.h>

      let ptr = withUnsafePointer(to: &addr) {
        return UnsafePointer<UInt8>(OpaquePointer($0))
      }
      
      let address = Data(bytes: ptr, count: MemoryLayout<sockaddr_in>.size)
      if CFSocketSetAddress(sock, address as CFData!) != CFSocketError.success { //kCFSocketSuccess {
        CFSocketInvalidate(sock)
        print("TSocketServer: Could not bind to address")
        return nil
      }
      
    } else {
      print("TSocketServer: No server socket")
      return nil
    }
    
    // wrap it in a file handle so we can get messages from it
    socketFileHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    
    // throw away our socket
    CFSocketInvalidate(sock)
    
    // register for notifications of accepted incoming connections
    NotificationCenter.default.addObserver(forName: .NSFileHandleConnectionAccepted,
                                             object: nil, queue: nil) {
      [weak self] notification in
      guard let strongSelf = self else { return }
      strongSelf.connectionAcctepted(strongSelf.socketFileHandle)
      
    }
    
    // tell socket to listen
    socketFileHandle.acceptConnectionInBackgroundAndNotify()
    
    print("TSocketServer: Listening on TCP port \(port)")
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  func connectionAcctepted(_ socket: FileHandle) {
    // Now that we have a client connected, handle the request on queue
    processingQueue.async {
      self.handleClientConnection(socket)
    }
  }
  
  func handleClientConnection(_ clientSocket: FileHandle) {
    
    let transport = TFileHandleTransport(fileHandle: clientSocket)
    let processor = processorFactory.processor(for: transport)
    
    let inProtocol = inputProtocolFactory.newProtocol(on: transport)
    let outProtocol = outputProtocolFactory.newProtocol(on: transport)
    
    do {
      try processor.process(on: inProtocol, outProtocol: outProtocol)
    } catch let error {
      print("Error processign request: \(error)")
    }
    DispatchQueue.main.async {
      NotificationCenter.default
        .post(name: Notification.Name(rawValue: TSocketServerClientConnectionFinished),
                              object: self,
                              userInfo: [TSocketServerProcessorKey: processor,
                                         TSocketServerTransportKey: transport])
    }
  }
}





