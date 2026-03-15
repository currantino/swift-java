import JExtractSwiftLib
import SwiftJavaConfigurationShared
import Testing

@Suite
struct KotlinFunctionTests {

  let inputFile =
    """
    public func voidFunc()

    public func add(a: Int, b: Int) -> Int

    public func id(x: String) -> String

    public func voidFuncWithOneArg(x: String)

    public func maybeTakeInt(i: Int?)
    """

  @Test("Kotlin: voidFunc() descriptor object")
  func kotlin_voidFunc_descriptor() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      expectedChunks: [
        """
        private object swiftjava_SwiftModule_voidFunc {
          @JvmField
          val DESC: FunctionDescriptor = FunctionDescriptor.ofVoid()
          @JvmField
          val ADDR: MemorySegment =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_voidFunc")
          @JvmField
          val HANDLE: MethodHandle = Linker.nativeLinker().downcallHandle(ADDR, DESC)
          @JvmStatic
          fun call() {
              HANDLE.invokeExact()
          }
        """
      ]
    )
  }

  @Test("Kotlin: voidFunc() wrapper method")
  func kotlin_voidFunc_wrapper() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func voidFunc()
         * }
         */
        @JvmStatic
        public fun voidFunc() {
          swiftjava_SwiftModule_voidFunc.call()
        ...
        """
      ]
    )
  }

  @Test("Kotlin: add(a:b:) descriptor object")
  func kotlin_add_descriptor() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      expectedChunks: [
        """
        private object swiftjava_SwiftModule_add_a_b {
          @JvmField
          val DESC: FunctionDescriptor = FunctionDescriptor.of(
            /* return type */SwiftValueLayout.SWIFT_INT,
            /* a: */SwiftValueLayout.SWIFT_INT,
            /* b: */SwiftValueLayout.SWIFT_INT
          )
          @JvmField
          val ADDR: MemorySegment =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_add_a_b")
          @JvmField
          val HANDLE: MethodHandle = Linker.nativeLinker().downcallHandle(ADDR, DESC)
          @JvmStatic
          fun call(a: Long, b: Long): Long {
              return HANDLE.invokeExact(a, b) as Long
          }
        """
      ]
    )
  }

  @Test("Kotlin: add(a:b:) wrapper method")
  func kotlin_add_wrapper() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func add(a: Int, b: Int) -> Int
         * }
         */
        @JvmStatic
        public fun add(a: Long, b: Long): Long {
          return swiftjava_SwiftModule_add_a_b.call(a, b)
        ...
        """
      ]
    )
  }

  @Test("Kotlin: add(a:b:) descriptor C signature")
  func kotlin_add_descriptor_cSignature() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      expectedChunks: [
        """
        /**
         * ```c
         * ptrdiff_t swiftjava_SwiftModule_add_a_b(ptrdiff_t a, ptrdiff_t b)
         * ```
         */
        """
      ]
    )
  }

  @Test("Kotlin: add(a:b:) wrapper returns descriptor call")
  func kotlin_add_wrapper_returnsCall() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      expectedChunks: [
        """
        @JvmStatic
        public fun add(a: Long, b: Long): Long {
          return swiftjava_SwiftModule_add_a_b.call(a, b)
        """
      ]
    )
  }

  @Test("Kotlin: voidFuncWithOneArg(x:) descriptor object")
  func kotlin_voidFuncWithOneArg_descriptor() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      expectedChunks: [
        """
        private object swiftjava_SwiftModule_voidFuncWithOneArg_x {
          @JvmField
          val DESC: FunctionDescriptor = FunctionDescriptor.ofVoid(
            /* x: */SwiftValueLayout.SWIFT_POINTER
          )
          @JvmField
          val ADDR: MemorySegment =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_voidFuncWithOneArg_x")
          @JvmField
          val HANDLE: MethodHandle = Linker.nativeLinker().downcallHandle(ADDR, DESC)
          @JvmStatic
          fun call(x: java.lang.foreign.MemorySegment) {
              HANDLE.invokeExact(x)
          }
        """
      ]
    )
  }

  @Test("Kotlin: voidFuncWithOneArg(x:) wrapper method")
  func kotlin_voidFuncWithOneArg_wrapper() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func voidFuncWithOneArg(x: String)
         * }
         */
        @JvmStatic
        public fun voidFuncWithOneArg(x: String) {
          Arena.ofConfined().use { arena ->
            swiftjava_SwiftModule_voidFuncWithOneArg_x.call(SwiftRuntime.toCString(x, arena))
        ...
        """
      ]
    )
  }

  @Test("Kotlin: maybeTakeInt(i:) descriptor object")
  func kotlin_maybeTakeInt_descriptor() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      expectedChunks: [
        """
        private object swiftjava_SwiftModule_maybeTakeInt_i {
          @JvmField
          val DESC: FunctionDescriptor = FunctionDescriptor.ofVoid(
            /* i: */SwiftValueLayout.SWIFT_POINTER
          )
          @JvmField
          val ADDR: MemorySegment =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_maybeTakeInt_i")
          @JvmField
          val HANDLE: MethodHandle = Linker.nativeLinker().downcallHandle(ADDR, DESC)
          @JvmStatic
          fun call(i: java.lang.foreign.MemorySegment) {
              HANDLE.invokeExact(i)
          }
        """
      ]
    )
  }

  @Test("Kotlin: maybeTakeInt(i:) wrapper nullability")
  func kotlin_maybeTakeInt_wrapper_nullability() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      expectedChunks: [
        """
        @JvmStatic
        public fun maybeTakeInt(i: Long?) {
          Arena.ofConfined().use { arena ->
            swiftjava_SwiftModule_maybeTakeInt_i.call(SwiftRuntime.toOptionalSegmentLong(if (i == null) OptionalLong.empty() else OptionalLong.of(i), arena))
          }
        ...
        """
      ]
    )
  }

  @Test("Kotlin: id(x:) descriptor object")
  func kotlin_id_descriptor() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      expectedChunks: [
        """
        private object swiftjava_SwiftModule_id_x {
          @JvmField
          val DESC: FunctionDescriptor = FunctionDescriptor.of(
            /* return type */SwiftValueLayout.SWIFT_POINTER,
            /* x: */SwiftValueLayout.SWIFT_POINTER
          )
        ...
        """
      ]
    )
  }

  @Test("Kotlin: id(x:) wrapper method")
  func kotlin_id_wrapper() throws {
    try assertOutput(
      input: inputFile,
      .kotlin,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func id(x: String) -> String
         * }
         */
        @JvmStatic
        public fun id(x: String): String {
          Arena.ofConfined().use { arena ->
            return swiftjava_SwiftModule_id_x.call(SwiftRuntime.toCString(x, arena)).reinterpret(Long.MAX_VALUE).getString(0)
        ...
        """
      ]
    )
  }

  private func renderKotlinOutput(
    input: String,
    swiftModuleName: String = "SwiftModule"
  ) throws -> String {
    var config = Configuration()
    config.swiftModule = swiftModuleName

    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swiftinterface", text: input)

    let generator = FFMSwift2KotlinGenerator(
      config: config,
      translator: translator,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    var printer: CodePrinter = CodePrinter(mode: .accumulateAll)
    try generator.writeExportedKotlinSources(printer: &printer)
    return printer.finalize()
  }

}
