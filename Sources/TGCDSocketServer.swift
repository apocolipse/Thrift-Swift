//
//  TGCDSocketServer.swift
//  Thrift
//
//  Created by Christopher Simpson on 8/21/16.
//
//

#if os(Linux)
  import Glibc
  import Dispatch
#else
  import Darwin
#endif

import Foundation

open class GCDSocketServer {
  public let listenSocket4: Int32
  public let listenSocket6: Int32
  public let readSource4: DispatchSourceRead
  public let readSource6: DispatchSourceRead
  public let readQueue  = DispatchQueue(label: "gcdhttp.read.queue",
                                        qos: .default,
                                        attributes: .concurrent)
  public let writeQueue = DispatchQueue(label: "gcdhttp.write.queue",
                                        qos: .default,
                                        attributes: .concurrent)
  
  
  init?(port: UInt16, ipv6: Bool = true) {
    #if os(Linux)
      listenSocket4 = socket(PF_INET, Int32(SOCK_STREAM.rawValue), 0)
      listenSocket6 = socket(PF_INET6, Int32(SOCK_STREAM.rawValue), 0)
      var addr4 = sockaddr_in(sin_family: sa_family_t(AF_INET),
                              sin_port: in_port_t(port.bigEndian),
                              sin_addr: in_addr(s_addr: in_addr_t(0)),
                              sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
      
      var addr6 = sockaddr_in6(sin6_family: sa_family_t(AF_INET6),
                               sin6_port: in_port_t(port.bigEndian),
                               sin6_flowinfo: 0,
                               sin6_addr: in6_addr(),
                               sin6_scope_id: 0)
    #else
      listenSocket4 = socket(PF_INET, SOCK_STREAM, 0)
      listenSocket6 = socket(PF_INET6, SOCK_STREAM, 0)
      
      var addr4 = sockaddr_in(sin_len: UInt8(MemoryLayout<sockaddr_in>.size),
                              sin_family: sa_family_t(AF_INET),
                              sin_port: in_port_t(port.bigEndian),
                              sin_addr: in_addr(s_addr: in_addr_t(0)),
                              sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
      
      var addr6 = sockaddr_in6(sin6_len: UInt8(MemoryLayout<sockaddr_in6>.size),
                               sin6_family: sa_family_t(AF_INET6),
                               sin6_port: in_port_t(port.bigEndian),
                               sin6_flowinfo: 0,
                               sin6_addr: in6_addr(),
                               sin6_scope_id: 0)
    #endif
    
    var yes: Int32 = 1
    
    setsockopt(listenSocket4, SOL_SOCKET, SO_REUSEADDR, &yes, UInt32(MemoryLayout<Int32>.size))
    setsockopt(listenSocket6, SOL_SOCKET, SO_REUSEADDR, &yes, UInt32(MemoryLayout<Int32>.size))
    
    let addr4ptr = withUnsafePointer(to: &addr4){ UnsafePointer<sockaddr>(OpaquePointer($0)) }
    let addr6ptr = withUnsafePointer(to: &addr6){ UnsafePointer<sockaddr>(OpaquePointer($0)) }
    
    let bound4 = bind(listenSocket4, addr4ptr, UInt32(MemoryLayout<sockaddr_in>.size))
    let bound6 = bind(listenSocket6, addr6ptr, UInt32(MemoryLayout<sockaddr_in6>.size))
    if bound4 != 0 || bound6 != 0 {
      print("Error binding sockets")
      return nil
    }
    
    readSource4 = DispatchSource.makeReadSource(fileDescriptor: listenSocket4, queue: readQueue)
    readSource6 = DispatchSource.makeReadSource(fileDescriptor: listenSocket6, queue: readQueue)
  
    readSource4.setEventHandler(handler: {
      var addr = sockaddr()
      var addrlen = socklen_t(MemoryLayout<sockaddr>.size)
      let newSock = accept(self.listenSocket4, &addr, &addrlen)
      self.handleClientConnection(clientSocket: newSock)
    })
    
    readSource6.setEventHandler(handler: {
      var addr = sockaddr()
      var addrlen = socklen_t(MemoryLayout<sockaddr>.size)
      let newSock = accept(self.listenSocket4, &addr, &addrlen)
      self.handleClientConnection(clientSocket: newSock)
    })
    
  }
  
  open func handleClientConnection(clientSocket: Int32) {
    let writeSource = DispatchSource.makeWriteSource(fileDescriptor: clientSocket, queue: writeQueue)
    writeSource.setEventHandler(handler: {
      
    })
    writeSource.resume()
  }
  
  public func serve() {
    listen(listenSocket4, 128)
    readSource4.resume()
    
    listen(listenSocket6, 128)
    readSource6.resume()
  }
  
}
