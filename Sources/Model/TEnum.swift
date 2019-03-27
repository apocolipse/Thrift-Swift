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

public protocol TEnum: TSerializable, RawRepresentable, Hashable, Codable {
    init?(rawValue: Int32)
    var rawValue: Int32 { get }

    static var defaultValue: Self { get }
}

extension TEnum {
    public static var thriftType: TType {
        return .i32
    }

	public func hash(into hasher: inout Hasher) {
		hasher.combine(rawValue)
	}

    public func write(to proto: TProtocol) throws {
        try proto.write(rawValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(rawValue)
    }

    public init() {
        self = Self.defaultValue
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let rawValue = try container.decode(Int32.self)
        self = Self(rawValue: rawValue) ?? Self.defaultValue
    }
}
