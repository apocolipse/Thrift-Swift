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


/// Thrift Enum extension to RawRepresentable
/// All Thrift Enums are Int32, so declarations
/// Only need to conform to Int32, TSerializable
extension RawRepresentable where RawValue == Int32 {
  public static var thriftType: TType { return .i32 }
  public var hashValue: Int { return rawValue.hashValue }
  
  public static func read(from proto: TProtocol) throws -> Self {
    let raw: RawValue = try proto.read() as Int32
    guard let ret = Self(rawValue: raw) else {
      throw TProtocolError(error: TProtocolError.ErrorCase.invalidData,
                           message: "Invalid enum value (\(raw)) for \(Self.self)")
    }
    return ret
  }
  
  public func write(to proto: TProtocol) throws {
    try proto.write(rawValue)
  }
}

