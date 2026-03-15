import JExtractSwiftLib
import Testing

@Suite
struct KotlinStringPassingTests {

  let inputFile =
    """
    public func echo(string: String) -> String
    
    public func echoOptionalStr(string: String?) -> String?
    """

  @Test("Kotlin: echo(string:) descriptor object")
  func kotlin_echo_descriptor() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      swiftModuleName: "SwiftModule",
      expectedChunks: [
        """
        private object swiftjava_SwiftModule_echo_string {
          @JvmField
          val DESC: FunctionDescriptor = FunctionDescriptor.of(
            /* return type */SwiftValueLayout.SWIFT_POINTER,
            /* string: */SwiftValueLayout.SWIFT_POINTER
          )
          @JvmField
          val ADDR: MemorySegment =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_echo_string")
          @JvmField
          val HANDLE: MethodHandle = Linker.nativeLinker().downcallHandle(ADDR, DESC)
          @JvmStatic
          fun call(string: java.lang.foreign.MemorySegment): java.lang.foreign.MemorySegment {
            return HANDLE.invokeExact(string) as java.lang.foreign.MemorySegment
          }
        """,
      ]
    )
  }

  @Test("Kotlin: echo(string:) wrapper method with arena")
  func kotlin_echo_wrapper() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      swiftModuleName: "SwiftModule",
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func echo(string: String) -> String
         * }
         */
        @JvmStatic
        public fun echo(string: String): String {
          Arena.ofConfined().use { arena ->
            return swiftjava_SwiftModule_echo_string.call(SwiftRuntime.toCString(string, arena)).reinterpret(Long.MAX_VALUE).getString(0)
          }
        }
        """,
      ]
    )
  }

  @Test("Kotlin: echoOptionalStr(string:) descriptor object")
  func kotlin_echoOptionalStr_descriptor() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      swiftModuleName: "SwiftModule",
      expectedChunks: [
        """
        private object swiftjava_SwiftModule_echoOptionalStr_string {
          @JvmField
          val DESC: FunctionDescriptor = FunctionDescriptor.of(
            /* return type */SwiftValueLayout.SWIFT_POINTER,
            /* string: */SwiftValueLayout.SWIFT_POINTER
          )
          @JvmField
          val ADDR: MemorySegment =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_echoOptionalStr_string")
          @JvmField
          val HANDLE: MethodHandle = Linker.nativeLinker().downcallHandle(ADDR, DESC)
          @JvmStatic
          fun call(string: java.lang.foreign.MemorySegment): java.lang.foreign.MemorySegment {
            return HANDLE.invokeExact(string) as java.lang.foreign.MemorySegment
          }
        """,
      ]
    )
  }

  @Test("Kotlin: echoOptionalStr(string:) wrapper method with arena")
  func kotlin_echoOptionalStr_wrapper() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      swiftModuleName: "SwiftModule",
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func echoOptionalStr(string: String?) -> String?
         * }
         */
        @JvmStatic
        public fun echoOptionalStr(string: String?): String? {
          Arena.ofConfined().use { arena ->
            val result = swiftjava_SwiftModule_echoOptionalStr_string.call(if (string == null) MemorySegment.NULL else SwiftRuntime.toCString(string, arena))
            return if (result.address() == 0L) null else result.reinterpret(Long.MAX_VALUE).getString(0)
          }
        }
        """,
      ]
    )
  }

}
