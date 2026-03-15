package com.example.kotlin

import com.example.swift.*
import org.swift.swiftkit.core.SwiftLibraries

fun main() {
    println("Property: java.library.path = ${SwiftLibraries.getJavaLibraryPath()}")
    examples()
}

fun examples() {
    assert(echoInt(2) == 2)
    assert(echoStr("abc") == "abc")
    println(getI32())
    println(isBool())
    println(getLong())
    println(getDouble())
    println(getStr())
    setStr("some str")
    assert(getStr() == "some str")
    setBool(false)
    println(isBool())
    voidFunction()
    voidFunctionWithoutReturnTypeSpecifier()
    anotherFileFunction()
    assert(echoOptionalStr(null) == null)
    assert(echoOptionalStr("not null") == "not null")
}