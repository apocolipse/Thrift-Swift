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

public class TProtocolUtil {
  public class func skip(type: TType, on proto: TProtocol) throws {
    switch type {
    case .bool:   _ = try proto.read() as Bool
    case .byte:   _ = try proto.read() as UInt8
    case .i16:    _ = try proto.read() as Int16
    case .i32:    _ = try proto.read() as Int32
    case .i64:    _ = try proto.read() as Int64
    case .double: _ = try proto.read() as Double
    case .string: _ = try proto.read() as String
    
    case .struct:
      _ = try proto.readStructBegin()
      while true {
        let (_, fieldType, _) = try proto.readFieldBegin()
        if fieldType == .stop {
          break
        }
        try TProtocolUtil.skip(type: fieldType, on: proto)
        try proto.readFieldEnd()
      }
      try proto.readStructEnd()
    
      
    case .map:
      let (keyType, valueType, size) = try proto.readMapBegin()
      for _ in 0..<size {
        try TProtocolUtil.skip(type: keyType, on: proto)
        try TProtocolUtil.skip(type: valueType, on: proto)
      }
      try proto.readMapEnd()

      
    case .set:
      let (elemType, size) = try proto.readSetBegin()
      for _ in 0..<size {
        try TProtocolUtil.skip(type: elemType, on: proto)
      }
      try proto.readSetEnd()
      
    case .list:
      let (elemType, size) = try proto.readListBegin()
      for _ in 0..<size {
        try TProtocolUtil.skip(type: elemType, on: proto)
      }
      try proto.readListEnd()
    default:
      return
    }
  }
}
