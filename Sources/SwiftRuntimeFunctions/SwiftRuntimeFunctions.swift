//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#else
import Glibc
#endif

@_silgen_name("getTypeByStringByteArray")
public func getTypeByStringByteArray(_ name: UnsafePointer<UInt8>) -> Any.Type? {
  let string = String(cString: name)
  let type = _typeByName(string)
  precondition(type != nil, "Unable to find type for name: \(string)!")
  return type
}

@_silgen_name("swift_retain")
public func _swiftjava_swift_retain(object: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer

@_silgen_name("swift_release")
public func _swiftjava_swift_release(object: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer

@_silgen_name("swift_retainCount")
public func _swiftjava_swift_retainCount(object: UnsafeMutableRawPointer) -> Int

@_silgen_name("swift_isUniquelyReferenced")
public func _swiftjava_swift_isUniquelyReferenced(object: UnsafeMutableRawPointer) -> Bool

@_alwaysEmitIntoClient @_transparent
func _swiftjava_withHeapObject<R>(
  of object: AnyObject,
  _ body: (UnsafeMutableRawPointer) -> R
) -> R {
  defer { _fixLifetime(object) }
  let unmanaged = Unmanaged.passUnretained(object)
  return body(unmanaged.toOpaque())
}

/// Convert an optional C string pointer into an optional Swift String.
///
/// This is used by generated cdecl thunks for `String?` parameters.
public func swiftjava_optionalStringFromCString(_ value: UnsafePointer<Int8>?) -> String? {
  guard let value else {
    return nil
  }
  return String(cString: value)
}

/// Duplicate a Swift String as an owned C string pointer.
///
/// The pointer is suitable for immediate FFM consumption.
public func swiftjava_copyCString(_ value: String) -> UnsafePointer<Int8> {
  let duplicated = strdup(value)
  precondition(duplicated != nil, "Failed to allocate C string copy")
  return UnsafePointer(duplicated!)
}

/// Duplicate an optional Swift String as an optional owned C string pointer.
public func swiftjava_copyOptionalCString(_ value: String?) -> UnsafePointer<Int8>? {
  guard let value else {
    return nil
  }
  return swiftjava_copyCString(value)
}
