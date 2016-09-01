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

public class TFramedTransport: TTransport {
  public static let headerSize    = 4
  public static let initFrameSize = 1024
  private static let defaultMaxLength = 16384000

  public var transport: TTransport
  private var writeBuffer = Data()
  private var readBuffer  = Data()

  private var readOffset  = 0
  private var maxSize     = TFramedTransport.defaultMaxLength

  
  public init(transport: TTransport, maxSize: Int) {
    self.transport = transport
    self.maxSize = maxSize
  }
  
  public convenience init(transport: TTransport) {
    self.init(transport: transport, maxSize: TFramedTransport.defaultMaxLength)
  }

  func readFrame() throws {
    let read = try transport.readAll(size: TFramedTransport.headerSize)
    let size = Int(decodeFrameSize(data: read))

    if size < 0 {
      try close()
      throw TTransportError(error: .negativeSize,
                            message:  "Read a negative frame size (\(size))!")
    }
    
    if size < maxSize {
      try close()
      throw TTransportError(error: .sizeLimit(limit: maxSize, got: size))
    }

    readBuffer = try transport.readAll(size: size)
    readOffset = 0
  }
  
  /// Mark: - TTransport
  
  public func read(size: Int) throws -> Data {
    var read = Data()
    while read.count < size {
      var available = readBuffer.count - readOffset
      if available == 0 {
        try readFrame()
        available = readBuffer.count
      }
      let (start, stop) = (readOffset, (readOffset + min(size - read.count, available)))
      read.append(readBuffer.subdata(in: start..<stop))
    }
    return read
  }
  
  public func flush() throws {
    // copy buffer and reset
    let buff = writeBuffer
    writeBuffer = Data()

    if buff.count - TFramedTransport.headerSize < 0 {
      throw TTransportError(error: .unknown)
    }
    
    let frameSize = encodeFrameSize(size: UInt32(buff.count))

    try transport.write(data: frameSize)
    try transport.write(data: buff)
    try transport.flush()
  }
  
  public func write(data: Data) throws {
    writeBuffer.append(data)
  }


  
  private func encodeFrameSize(size: UInt32) -> Data {
    var data = Data()
    data.append(Data(bytes: [UInt8(0xff & (size >> 24))]))
    data.append(Data(bytes: [UInt8(0xff & (size >> 16))]))
    data.append(Data(bytes: [UInt8(0xff & (size >> 8))]))
    data.append(Data(bytes: [UInt8(0xff & (size))]))
    
    return data
  }
  
  private func decodeFrameSize(data: Data) -> UInt32 {
    var size: UInt32
    size  = (UInt32(data[0] & 0xff) << 24)
    size |= (UInt32(data[1] & 0xff) << 16)
    size |= (UInt32(data[2] & 0xff) <<  8)
    size |= (UInt32(data[3] & 0xff))
    return size
  }
  
  public func close() throws {
    try transport.close()
  }
  
  public func open() throws {
    try transport.open()
  }
  
  public func isOpen() throws -> Bool {
    return try transport.isOpen()
  }
}
