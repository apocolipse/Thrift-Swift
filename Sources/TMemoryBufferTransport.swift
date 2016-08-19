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

public class TMemoryBufferTransport : TTransport {
  public private(set) var buffer = Data()
  
  public private(set) var position = 0

  public var bytesRemainingInBuffer: Int {
    return buffer.count - position
  }
  
  public func consumeBuffer(size: Int) {
    position += size
  }
  public func clear() {
    buffer = Data()
  }

  public init() { }
  public convenience init(buffer: Data) {
    self.init()
    self.buffer = buffer
  }
  
  public func reset(buffer: Data = Data()) {
    reset(buffer: buffer, offset: 0, size: buffer.count)
  }
  
  public func reset(buffer buff: Data, offset: Int, size: Int) {
    buffer = buff
    position = offset
  }
  
  public func read(size: Int) throws -> Data {
    let amountToRead = min(bytesRemainingInBuffer, size)
    if amountToRead > 0 {
      let ret = buffer.subdata(in: Range(uncheckedBounds: (lower: position, upper: position + amountToRead)))
      position += ret.count
      return ret
    }
    return Data()
  }
  
  public func write(data: Data) throws {
    buffer.append(data)
  }
  
  public func flush() throws {
    reset()
  }
}
