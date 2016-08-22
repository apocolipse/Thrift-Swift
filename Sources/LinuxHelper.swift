//
//  LinuxHelper.swift
//  Thrift
//
//  Created by Christopher Simpson on 8/22/16.
//
//

import Foundation
import CoreFoundation

#if os(Linux)

// Data doesn't have append byte yet, or + funcs
extension Data {
  mutating func append(_ byte: UInt8) {
    return self.append(Data(bytes: [byte]))
  }
  static func +(lhs: Data, rhs: Data) -> Data {
    var out = lhs
    out.append(rhs)
    return out
  }
  
  mutating func +=( lhs: inout Data, rhs: Data) {
    lhs.append(rhs)
  }
}
  
struct CFStreamPropertyKey : RawRepresentable {
  private let raw: CFString
  init(rawValue: CFString) {
    raw = rawValue
  }
  init(_ val: CFString) {
    self.init(rawValue: val)
  }
  var rawValue: CFString { return raw }
}
  
public typealias OutputStream = NSOutputStream
#else
#endif

extension CFStreamPropertyKey {
  static let shouldCloseNativeSocket  = CFStreamPropertyKey(kCFStreamPropertyShouldCloseNativeSocket)
  // Exists as Stream.PropertyKey.socketSecuritylevelKey but doesn't work with CFReadStreamSetProperty
  static let socketSecurityLevel      = CFStreamPropertyKey(kCFStreamPropertySocketSecurityLevel)
  static let SSLSettings              = CFStreamPropertyKey(kCFStreamPropertySSLSettings)
}
