public var i32 : Int32  = 1

public var long : Int64 = 2

public var bool : Bool = true

public var double : Double = 0.42

public var str : String = "hello from swift!"

public func echoStr(s: String) -> String {
  return s
}

public func echoInt(x: Int32) -> Int32 {
  x
}

public func funcWithOptionalParam(x: Int32?) -> Int32 {
  return x ?? -1
}

public func echoOptionalStr(s: String?) -> String? {
  s
}

public func voidFunction() -> Void {
  print("void func from swift")
}

public func voidFunctionWithoutReturnTypeSpecifier() {
  print("void func from swift")
}
