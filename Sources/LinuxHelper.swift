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
/// Extensions for Linux for incomplete Foundation API's.
/// swift-corelibs-foundation is not yet 1:1 with OSX/iOS Foundation

extension URLSession {
  // Current one uses NSURLRequest which doesn't currently bridge
  @discardableResult
  open func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
    return dataTask(with: request._bridgeToObjectiveC(), completionHandler: completionHandler)
  }
}

extension CFSocketError {
  public static let success = kCFSocketSuccess
}
  
extension UInt {
  public static func &(lhs: UInt, rhs: Int) -> UInt {
    let cast = unsafeBitCast(rhs, to: UInt.self)
    return lhs & cast
  }
}

#else
extension CFStreamPropertyKey {
  static let shouldCloseNativeSocket  = CFStreamPropertyKey(kCFStreamPropertyShouldCloseNativeSocket)
  // Exists as Stream.PropertyKey.socketSecuritylevelKey but doesn't work with CFReadStreamSetProperty
  static let socketSecurityLevel      = CFStreamPropertyKey(kCFStreamPropertySocketSecurityLevel)
  static let SSLSettings              = CFStreamPropertyKey(kCFStreamPropertySSLSettings)
}
#endif
