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


#if os(Linux)
  import Glibc
  import Dispatch
#else
  import Darwin
#endif

import Foundation
import CoreFoundation

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


extension Stream.PropertyKey {
  static let SSLPeerTrust = Stream.PropertyKey(kCFStreamPropertySSLPeerTrust as String)
}

extension in_addr {
  public init?(hostent: hostent?) {
    guard let host = hostent, host.h_addr_list != nil else {
      return nil
    }
    self.init()
    memcpy(&self, host.h_addr_list.pointee, Int(host.h_length))
  }
}



/// TCFSocketTransport, uses CFSockets and (NS)Stream's
public class TCFSocketTransport: TStreamTransport {
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

extension TCFSocketTransport: StreamDelegate { }



/// TSocketTransport, posix sockets.  Supports IPv4 only for now
public class TSocketTransport : TTransport {
  public var socketDescriptor: Int32
  
  
  
  /// Initialize from an already set up socketDescriptor.
  /// Expects socket thats already bound/connected (i.e. from listening)
  ///
  /// - parameter socketDescriptor: posix socket descriptor (Int32)
  public init(socketDescriptor: Int32) {
    self.socketDescriptor = socketDescriptor
  }
  
  
  public convenience init?(hostname: String, port: Int) {
    guard let hp = gethostbyname(hostname.cString(using: .utf8)!)?.pointee,
          let hostAddr = in_addr(hostent: hp) else {
      return nil
    }
    
    
    
    #if os(Linux)
      let sock = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
      var addr = sockaddr_in(sin_family: sa_family_t(AF_INET),
                              sin_port: in_port_t(htons(UInt16(port))),
                              sin_addr: hostAddr,
                              sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
    #else
      let sock = socket(AF_INET, SOCK_STREAM, 0)
      
      var addr = sockaddr_in(sin_len: UInt8(MemoryLayout<sockaddr_in>.size),
                              sin_family: sa_family_t(AF_INET),
                              sin_port: in_port_t(htons(UInt16(port))),
                              sin_addr: in_addr(s_addr: in_addr_t(0)),
                              sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
      
    #endif

    let addrPtr = withUnsafePointer(to: &addr){ UnsafePointer<sockaddr>(OpaquePointer($0)) }
    
    let connected = connect(sock, addrPtr, UInt32(MemoryLayout<sockaddr_in>.size))
    if connected != 0 {
      print("Error binding to host: \(hostname) \(port)")
      return nil
    }
    
    self.init(socketDescriptor: sock)
  }
  
  
  public func readAll(size: Int) throws -> Data {
    var out = Data()
    while out.count < size {
      var buff = Data(capacity: size)
      let readBytes = Sys.read(socketDescriptor, &buff, size)
      // FIXME: Handle EOF
      out.append(buff.subdata(in: 0..<readBytes))
    }
    return out
  }
  
  public func read(size: Int) throws -> Data {
    var buff = Data(capacity: size)
    let readBytes = Sys.read(socketDescriptor, &buff, size)
    return buff.subdata(in: 0..<readBytes)
  }
  
  public func write(data: Data) {
    var bytesToWrite = data.count
    var writeBuffer = data
    while bytesToWrite > 0 {
      let written = writeBuffer.withUnsafeBytes {
        Sys.write(socketDescriptor, $0, writeBuffer.count)
      }
      writeBuffer = writeBuffer.subdata(in: written ..< writeBuffer.count)
      bytesToWrite -= written
    }
  }
  
  public func flush() throws {
    // nothing to do
  }
  
  public func close() {
    shutdown(socketDescriptor, Int32(SHUT_RDWR))
    _ = Sys.close(socketDescriptor)
  }
}



public class TAsyncSocketTransport: TAsyncTransport {
  public let socketDescriptor: Int32
  private var writeBuffer = Data()
  private var readBuffer = Data()
  private var readPtr = 0
  
  private var ioQueue = DispatchQueue(label: "GCDSocket.io.queue")
  private var readSource: DispatchSourceRead
  private var writeSource: DispatchSourceWrite
  private var bufferLock = DispatchQueue(label: "bufferLock")
  private var hasDataToWrite: Bool {
    return writeBuffer.count != 0
  }
  private var flushHandler: (() -> Void)?
  
  public init(socket: Int32) {
    socketDescriptor = socket
    
    readSource = DispatchSource.makeReadSource(fileDescriptor: socketDescriptor, queue: ioQueue)
    writeSource = DispatchSource.makeWriteSource(fileDescriptor: socketDescriptor, queue: ioQueue)
    
  }
  
  public convenience init?(hostname: String, port: Int) {
    
    guard let hp = gethostbyname(hostname.cString(using: .utf8)!)?.pointee else {
      return nil
    }
    
    
    var hostAddr = in_addr()
    memcpy(&hostAddr, hp.h_addr_list.pointee, Int(hp.h_length))
    #if os(Linux)
      let sock = socket(AF_INET, Int32(SOCK_STREAM.rawValue), Int32(IPPROTO_TCP))
      var addr = sockaddr_in(sin_family: sa_family_t(AF_INET),
                             sin_port: in_port_t(htons(UInt16(port))),
                             sin_addr: hostAddr,
                             sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
    #else
      let sock = socket(AF_INET, SOCK_STREAM, Int32(IPPROTO_TCP))
      var addr = sockaddr_in(sin_len: UInt8(MemoryLayout<sockaddr_in>.size),
                             sin_family: sa_family_t(AF_INET),
                             sin_port: in_port_t(htons(UInt16(port))),
                             sin_addr: hostAddr,
                             sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
    #endif
    
    var yes: Int32 = 1
    
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, UInt32(MemoryLayout<Int32>.size))
    
    let addrPtr = withUnsafePointer(to: &addr){ UnsafePointer<sockaddr>(OpaquePointer($0)) }
    
    let connected = connect(sock, addrPtr, UInt32(MemoryLayout<sockaddr_in>.size))
    if connected != 0 {
      print("Error binding to host: \(hostname) \(port)")
      return nil
    }
    
    self.init(socket: sock)
  }
  
  
  private func setupIOHandlers() {
    // Read
    readSource.setEventHandler(handler: {
      self.bufferLock.sync {
        var buff = Data(capacity: 1)
        let readBytes = Sys.read(self.socketDescriptor, &buff, 1)
        if readBytes == 1 {
          self.readBuffer.append(buff)
        }
      }
    })
    readSource.resume()
    
    // Write
    writeSource.setEventHandler(handler: {
      self.bufferLock.sync {
        let written = self.writeBuffer.withUnsafeBytes({
          return Sys.write(self.socketDescriptor, $0, self.writeBuffer.count)
        })
        // Reset the buffer with remaining unwritten data
        self.writeBuffer = self.writeBuffer.subdata(in: written..<self.writeBuffer.count)
        
        // call flush handler, it only exists if a flush(completion:) call sets it
        if !self.hasDataToWrite {
          self.flushHandler?()
        }
      }
      
    })
    writeSource.resume()
  }
  
  public func read(size: Int) -> Data {
    var buff = Data()
    bufferLock.sync {
      buff = self.readBuffer.subdata(in: 0..<min(size, self.readBuffer.count))
      self.readBuffer = self.readBuffer.subdata(in: min(size, self.readBuffer.count)..<self.readBuffer.count)
    }
    return buff
  }
  
  public func write(data: Data) {
    bufferLock.sync {
      self.writeBuffer.append(data)
    }
  }
  
  public func flush() throws {
    let completed = DispatchSemaphore(value: 0)
    var internalError: Error?
    
    flush() { _, error in
      internalError = error
      completed.signal()
    }
    
    _ = completed.wait(timeout: DispatchTime.distantFuture)
    
    if let error = internalError {
      throw error
    }
  }
  
  public func flush(_ completion: @escaping (TAsyncTransport, Error?) -> ()) {
    flushHandler = {
      self.flushHandler = nil
      completion(self, nil)
    }
  }
  
  public func close() {
    shutdown(socketDescriptor, Int32(SHUT_RDWR))
    _ = Sys.close(socketDescriptor)
  }
}
