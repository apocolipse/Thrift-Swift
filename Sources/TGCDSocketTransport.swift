//
//  TGCDSocketTransport.swift
//  Thrift
//
//  Created by Christopher Simpson on 8/22/16.
//
//

#if os(Linux)
  import Glibc
  import Dispatch
#else
  import Darwin
#endif

import Foundation

public class GCDSocket {
  public let socketHandle: Int32
  private var writeBuffer = Data()
  private var readBuffer = Data()
  private var readPtr = 0
  
  private var ioQueue = DispatchQueue(label: "GCDSocket.io.queue")
  private var readSource: DispatchSourceRead
  private var writeSource: DispatchSourceWrite
  
  
  private struct Sys {
    #if os(Linux)
    static let read = Glibc.read
    static let write = Glibc.write
    static let close = GLibc.close
    #else
    static let read = Darwin.read
    static let write = Darwin.write
    static let close = Darwin.close
    #endif
  }
  
  init(socket: Int32) {
    socketHandle = socket
    
    readSource = DispatchSource.makeReadSource(fileDescriptor: socketHandle, queue: ioQueue)
    writeSource = DispatchSource.makeWriteSource(fileDescriptor: socketHandle, queue: ioQueue)
    
  }
  
  convenience init?(hostname: String, port: Int32) {
    
    guard let hp = gethostbyname(hostname.cString(using: .utf8)!) else {
      return nil
    }
    let hostAddr = in_addr(s_addr: UInt32(hp.pointee.h_addr_list.pointee!.pointee))

    #if os(Linux)
      let sock = socket(PF_INET, Int32(SOCK_STREAM.rawValue), 0)
      var addr4 = sockaddr_in(sin_family: sa_family_t(AF_INET),
                              sin_port: in_port_t(port.bigEndian),
                              sin_addr: hostAddr,
                              sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
    #else
      let sock = socket(PF_INET, SOCK_STREAM, 0)
      var addr = sockaddr_in(sin_len: UInt8(MemoryLayout<sockaddr_in>.size),
                             sin_family: sa_family_t(AF_INET),
                             sin_port: in_port_t(port.bigEndian),
                             sin_addr: hostAddr,
                             sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
    #endif
    var yes: Int32 = 1
    
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, UInt32(MemoryLayout<Int32>.size))
    
    let addrPtr = withUnsafePointer(to: &addr){ UnsafePointer<sockaddr>(OpaquePointer($0)) }
    
    let bound = bind(sock, addrPtr, UInt32(MemoryLayout<sockaddr_in>.size))
    if bound != 0 {
      print("Error binding to host: \(hostname) \(port)")
      return nil
    }
    self.init(socket: sock)
  }
  
  private func setupIOHandlers() {
    readSource.setEventHandler(handler: {
      var buff = Data(capacity: 1)
      let readBytes = Sys.read(self.socketHandle, &buff, 1)
      if readBytes == 1 {
        self.readBuffer.append(buff)
      }
    })
    readSource.resume()
    
    writeSource.setEventHandler(handler: {
      let written = self.writeBuffer.withUnsafeBytes({
        return Sys.write(self.socketHandle, $0, self.writeBuffer.count)
      })
      // Reset the buffer with remaining unwritten data
      self.writeBuffer = self.writeBuffer.subdata(in: written..<self.writeBuffer.count)
    })
    writeSource.resume()
  }
  
  public func read(size: Int) -> Data {
    let buff = readBuffer.subdata(in: 0..<size)
    readBuffer = readBuffer.subdata(in: size..<readBuffer.count)
    return buff
  }
  
  public func write(data: Data) {
    writeBuffer.append(data)
  }
  
  public func close() {
    shutdown(socketHandle, Int32(SHUT_RDWR))
    _ = Sys.close(socketHandle)
  }
}

public class TGCDSocketTransport : TTransport {
  let socket: GCDSocket
  
  public init?(hostname: String, port: Int) {
    guard let socket = GCDSocket(hostname: hostname, port: Int32(port)) else {
      return nil
    }
    self.socket = socket
  }
  
  public func read(size: Int) throws -> Data {
    return socket.read(size: size)
  }
  
  public func write(data: Data) throws {
    socket.write(data: data)
  }
  
  public func flush() throws {
    
  }
  
  public func close() {
    socket.close()
  }
}
