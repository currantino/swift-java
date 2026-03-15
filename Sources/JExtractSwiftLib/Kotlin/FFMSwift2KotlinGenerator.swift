import SwiftJavaConfigurationShared
import SwiftJavaJNICore
import SwiftSyntax
import SwiftSyntaxBuilder

import struct Foundation.URL

/// Generates Kotlin/JVM source files that call Swift through FFM
///
/// Swift thunks are created by `FFMSwift2JavaGenerator`
package class FFMSwift2KotlinGenerator: Swift2JavaGenerator {
  let log: Logger
  let config: Configuration
  let translationResult: AnalysisResult
  let swiftModuleName: String
  let javaPackage: String
  let swiftOutputDirectory: String
  let javaOutputDirectory: String
  let lookupContext: SwiftTypeLookupContext

  private let translator: Swift2JavaTranslator

  var javaPackagePath: String {
    javaPackage.replacingOccurrences(of: ".", with: "/")
  }

  var thunkNameRegistry: ThunkNameRegistry = .init()

  /// Cached Swift to Kotlin translation results. 'nil' value indicates failed translation
  var kotlinDecls: [ImportedFunc: KotlinFunctionDecl?] = [:]

  var expectedOutputSwiftFileNames: Set<String>

  package init(
    config: Configuration,
    translator: Swift2JavaTranslator,
    javaPackage: String,
    swiftOutputDirectory: String,
    javaOutputDirectory: String
  ) {
    self.log = Logger(label: "kotlin-generator", logLevel: translator.log.logLevel)
    self.config = config
    self.translator = translator
    swiftModuleName = translator.swiftModuleName
    self.javaPackage = javaPackage
    self.swiftOutputDirectory = swiftOutputDirectory
    self.javaOutputDirectory = javaOutputDirectory
    lookupContext = translator.lookupContext

    self.translationResult = translator.result

    if config.writeEmptyFiles ?? false {
      expectedOutputSwiftFileNames = Set(
        translator.inputs.compactMap { input -> String? in
          guard let fileName = input.path.split(separator: PATH_SEPARATOR).last else {
            return nil
          }
          guard fileName.hasSuffix(".swift") else {
            return nil
          }
          return String(fileName.replacing(".swift", with: "+SwiftJava.swift"))
        }
      )
      expectedOutputSwiftFileNames.insert("\(swiftModuleName)Module+SwiftJava.swift")
      expectedOutputSwiftFileNames.insert("Foundation+SwiftJava.swift")
    } else {
      expectedOutputSwiftFileNames = []
    }
  }

  func generate() throws {
    try writeSwiftThunkSources()
    log.info("Generated Swift thunk sources (module: '\(swiftModuleName)') in: \(swiftOutputDirectory)/")

    try writeExportedKotlinSources()
    log.info("Generated Kotlin sources (package: '\(javaPackage)') in: \(javaOutputDirectory)/")

    try writeSwiftExpectedEmptySources()
  }
}

// MARK: - Java -> Kotlin type mapping

extension FFMSwift2KotlinGenerator {

  /// standard Java to Kotlin type mappings.
  static let javaToKotlinTypeMap: [String: String] = [
    "java.lang.String": "String",
    "java.lang.Object": "Any",
    "java.lang.Boolean": "Boolean",
    "java.lang.Byte": "Byte",
    "java.lang.Character": "Char",
    "java.lang.Short": "Short",
    "java.lang.Integer": "Int",
    "java.lang.Long": "Long",
    "java.lang.Float": "Float",
    "java.lang.Double": "Double",
  ]

  /// Java to Kotlin type mapping
  static func kotlinType(for javaType: JavaType) -> String {
    switch javaType {
    case .boolean: return "Boolean"
    case .byte: return "Byte"
    case .char: return "Char"
    case .short: return "Short"
    case .int: return "Int"
    case .long: return "Long"
    case .float: return "Float"
    case .double: return "Double"
    case .void: return "Unit"
    case let .array(element):
      let elemType = kotlinType(for: element)
      switch element {
      case .boolean: return "BooleanArray"
      case .byte: return "ByteArray"
      case .char: return "CharArray"
      case .short: return "ShortArray"
      case .int: return "IntArray"
      case .long: return "LongArray"
      case .float: return "FloatArray"
      case .double: return "DoubleArray"
      default: return "Array<\(elemType)>"
      }
    case let .class(package, name, typeParameters):
      let fullName = "\(package ?? "").\(name)"
      if let kotlinName = Self.javaToKotlinTypeMap[fullName] {
        if typeParameters.isEmpty {
          return kotlinName
        }
        let params = typeParameters.map { kotlinType(for: $0) }.joined(separator: ", ")
        return "\(kotlinName)<\(params)>"
      }

      let base = package.map { "\($0).\(name)" } ?? name
      if typeParameters.isEmpty {
        return base
      }
      let params = typeParameters.map { kotlinType(for: $0) }.joined(separator: ", ")
      return "\(base)<\(params)>"
    }
  }

  /// map a Swift type to Kotlin source type
  static func kotlinType(for swiftType: SwiftType) -> String? {
    switch swiftType {
    case .optional(let wrapped):
      guard let wrappedType = kotlinType(for: wrapped) else {
        return nil
      }
      return "\(wrappedType)?"

    case .nominal(let nominal):
      if nominal.nominalTypeDecl.knownTypeKind == .string {
        return "String"
      }
      fallthrough

    case .genericParameter, .function, .metatype, .tuple, .existential, .opaque, .composite, .array:
      if let cType = try? CType(cdeclType: swiftType) {
        return kotlinType(for: cType.javaType)
      }
      return nil
    }
  }
}

// MARK: - Kotlin wrappers for swift terms

extension FFMSwift2KotlinGenerator {

  struct KotlinFunctionDecl {
    let name: String
    let signature: KotlinFunctionSignature
    let loweredSignature: LoweredFunctionSignature
  }

  struct KotlinFunctionSignature {
    let parameters: [KotlinParameter]
    let result: KotlinResult
    let isAsync: Bool
    let isThrowing: Bool
  }

  struct KotlinParameter {
    let name: String
    let swiftType: SwiftType
    let isNullable: Bool
  }

  struct KotlinResult {
    let swiftType: SwiftType
    let isNullable: Bool
    let isVoid: Bool
  }

  func kotlinDecl(for decl: ImportedFunc) -> KotlinFunctionDecl? {
    if let cached = kotlinDecls[decl] {
      return cached
    }

    let translated: KotlinFunctionDecl?
    do {
      let lowering = CdeclLowering(
        knownTypes: SwiftKnownTypes(symbolTable: lookupContext.symbolTable)
      )
      let loweredSignature = try lowering.lowerFunctionSignature(decl.functionSignature)

      let kotlinName: String =
        switch decl.apiKind {
        case .getter, .subscriptGetter:
          decl.javaGetterName
        case .setter, .subscriptSetter:
          decl.javaSetterName
        case .function, .initializer, .enumCase:
          decl.name
        }

      translated = KotlinFunctionDecl(
        name: kotlinName,
        signature: KotlinFunctionSignature(
          parameters: decl.functionSignature.parameters.enumerated().map { idx, param in
            KotlinParameter(
              name: param.parameterName ?? "_\(idx)",
              swiftType: param.type,
              isNullable: Self.swiftTypeIsNullable(param.type)
            )
          },
          result: KotlinResult(
            swiftType: decl.functionSignature.result.type,
            isNullable: Self.swiftTypeIsNullable(decl.functionSignature.result.type),
            isVoid: decl.functionSignature.result.type.isVoid
          ),
          isAsync: decl.functionSignature.isAsync,
          isThrowing: decl.functionSignature.isThrowing
        ),
        loweredSignature: loweredSignature
      )
    } catch {
      log.info("Failed to translate: '\(decl.swiftDecl.qualifiedNameForDebug)'; \(error)")
      translated = nil
    }

    kotlinDecls[decl] = translated
    return translated
  }

  private static func swiftTypeIsNullable(_ swiftType: SwiftType) -> Bool {
    switch swiftType {
    case .optional:
      return true
    case .nominal(let nominal):
      if nominal.nominalTypeDecl.knownTypeKind == .optional {
        return true
      }
      if nominal.nominalTypeDecl.name == "Optional" {
        return true
      }
      return false
    default:
      return false
    }
  }

}

extension FFMSwift2KotlinGenerator {
  package func writeExportedKotlinSources() throws {
    var printer = CodePrinter()
    try writeExportedKotlinSources(printer: &printer)
  }

  package func writeExportedKotlinSources(printer: inout CodePrinter) throws {
    let filename = "\(swiftModuleName).kt"
    log.debug("Printing Kotlin contents: \(filename)")
    printModule(&printer)

    if let outputFile = try printer.writeContents(
      outputDirectory: javaOutputDirectory,
      javaPackagePath: javaPackagePath,
      filename: filename
    ) {
      log.info("Generated: \(swiftModuleName + ".kt") (at \(outputFile.absoluteString))")
    }
  }
}


extension FFMSwift2KotlinGenerator {
  func printModule(_ printer: inout CodePrinter) {
    printHeader(&printer)
    printPackage(&printer)
    printImports(&printer)

    printModuleObject(&printer) { printer in
      for decl in self.translationResult.importedGlobalVariables {
        self.log.trace("Print imported decl: \(decl)")
        self.printFunctionDowncallMethods(&printer, decl)
      }

      for decl in self.translationResult.importedGlobalFuncs {
        self.log.trace("Print imported decl: \(decl)")
        self.printFunctionDowncallMethods(&printer, decl)
      }
    }

    for decl in self.translationResult.importedGlobalVariables {
      self.log.trace("Print toplevel imported decl: \(decl)")
      self.printToplevelDecl(&printer, decl)
    }

    for decl in self.translationResult.importedGlobalFuncs {
      self.log.trace("Print toplevel imported decl: \(decl)")
      self.printToplevelDecl(&printer, decl)
    }
  }

  func printHeader(_ printer: inout CodePrinter) {
    printer.print(
      """
      // Generated by jextract-swift
      // Swift module: \(swiftModuleName)

      """
    )
  }

  func printPackage(_ printer: inout CodePrinter) {
    guard !javaPackage.isEmpty else { return }
    printer.print(
      """
      package \(javaPackage)

      """
    )
  }

  func printImports(_ printer: inout CodePrinter) {
    Self.defaultKotlinImports.forEach({ printer.print("import \($0)") })
    printer.println()
  }

  static let defaultKotlinImports: [String] = [
    "org.swift.swiftkit.core.*",
    "org.swift.swiftkit.core.util.*",
    "org.swift.swiftkit.ffm.*",
    "org.swift.swiftkit.core.annotations.*",
    "java.lang.foreign.*",
    "java.lang.invoke.*",
    "java.util.*",
    "java.nio.charset.StandardCharsets",
  ]

  /// SwiftModule -> kotlin 'singleton' object with ffm setup
  func printModuleObject(_ printer: inout CodePrinter, body: (inout CodePrinter) -> Void) {
    printer.printBraceBlock("public object \(swiftModuleName)") { printer in
      printClassConstants(printer: &printer)

      printer.print(
        """
        @JvmStatic
        fun findOrThrow(symbol: String): MemorySegment {
            return SYMBOL_LOOKUP.find(symbol)
                .orElseThrow { UnsatisfiedLinkError("unresolved symbol: $symbol") }
        }
        """
      )

      printer.print(
        """
        @JvmField
        val SYMBOL_LOOKUP: SymbolLookup = run {
            if (SwiftLibraries.AUTO_LOAD_LIBS) {
                SwiftLibraries.loadLibraryWithFallbacks(SwiftLibraries.LIB_NAME_SWIFT_CORE)
                SwiftLibraries.loadLibraryWithFallbacks(SwiftLibraries.LIB_NAME_SWIFT_JAVA)
                SwiftLibraries.loadLibraryWithFallbacks(SwiftLibraries.LIB_NAME_SWIFT_RUNTIME_FUNCTIONS)
                SwiftLibraries.loadLibraryWithFallbacks(LIB_NAME)
            }

            if (PlatformUtils.isMacOS()) {
                SymbolLookup.libraryLookup(System.mapLibraryName(LIB_NAME), LIBRARY_ARENA)
                    .or(SymbolLookup.loaderLookup())
                    .or(Linker.nativeLinker().defaultLookup())
            } else {
                SymbolLookup.loaderLookup()
                    .or(Linker.nativeLinker().defaultLookup())
            }
        }
        """
      )

      body(&printer)
    }
  }

  func printClassConstants(printer: inout CodePrinter) {
    printer.print(
      """
      private const val LIB_NAME: String = "\(swiftModuleName)"
      @JvmField
      val LIBRARY_ARENA: Arena = Arena.ofAuto()
      """
    )
  }
}

// MARK: - Swift thunk generation via FFMSwift2JavaGenerator

extension FFMSwift2KotlinGenerator {

  package func writeSwiftThunkSources() throws {
    let ffmGenerator = FFMSwift2JavaGenerator(
      config: config,
      translator: translator,
      javaPackage: javaPackage,
      swiftOutputDirectory: swiftOutputDirectory,
      javaOutputDirectory: javaOutputDirectory
    )

    try ffmGenerator.writeSwiftThunkSources()

    thunkNameRegistry = ffmGenerator.thunkNameRegistry
    expectedOutputSwiftFileNames = ffmGenerator.expectedOutputSwiftFileNames
  }

  package func writeSwiftExpectedEmptySources() throws {
    let pendingFileCount = expectedOutputSwiftFileNames.count
    guard pendingFileCount > 0 else {
      return
    }

    log.info(
      "[swift-java] Write empty [\(expectedOutputSwiftFileNames.count)] 'expected' files in: \(swiftOutputDirectory)/"
    )

    for expectedFileName in expectedOutputSwiftFileNames {
      log.info("Write SwiftPM-'expected' empty file: \(expectedFileName.bold)")

      var printer = CodePrinter()
      printer.print("// Empty file generated on purpose")
      _ = try printer.writeContents(
        outputDirectory: swiftOutputDirectory,
        javaPackagePath: nil,
        filename: expectedFileName
      )
    }
  }
}
