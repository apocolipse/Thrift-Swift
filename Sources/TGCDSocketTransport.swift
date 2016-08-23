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

