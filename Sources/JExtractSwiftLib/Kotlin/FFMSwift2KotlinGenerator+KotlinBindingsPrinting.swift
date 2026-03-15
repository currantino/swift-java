import SwiftJavaJNICore
import SwiftSyntax

// MARK: - Kotlin FFM binding printing

extension FFMSwift2KotlinGenerator {

  private typealias KotlinBindingPrintContext = (
    kotlinDecl: KotlinFunctionDecl,
    methodName: String,
    swiftSignature: SwiftFunctionSignature,
    cFunction: CFunction,
    thunkObjectName: String,
    parameterDecls: [String],
    returnClause: String
  )


  private func makeKotlinBindingPrintContext(
    for decl: ImportedFunc,
    failureKind: String
  ) -> KotlinBindingPrintContext? {
    let kotlinDecl = self.kotlinDecl(for: decl)!
    let swiftSignature = decl.functionSignature
    let thunkName = thunkNameRegistry.functionThunkName(decl: decl)
    let cFunction = try! kotlinDecl.loweredSignature.cFunctionDecl(
      cName: thunkName
    )

    guard let parameterDecls = renderKotlinWrapperParameters(swiftSignature) else {
      log.info("Failed Kotlin \(failureKind) translation: '\(decl.swiftDecl.qualifiedNameForDebug)'; unsupported parameter type")
      return nil
    }

    guard
      swiftSignature.result.type.isVoid || Self.kotlinType(for: swiftSignature.result.type) != nil
    else {
      log.info("Failed Kotlin \(failureKind) translation: '\(decl.swiftDecl.qualifiedNameForDebug)'; unsupported result type")
      return nil
    }

    let returnClause =
      swiftSignature.result.type.isVoid
      ? ""
      : ": \(Self.kotlinType(for: swiftSignature.result.type)!)"

    return (
      kotlinDecl: kotlinDecl,
      methodName: kotlinDecl.name,
      swiftSignature: swiftSignature,
      cFunction: cFunction,
      thunkObjectName: kotlinIdentifier(thunkName),
      parameterDecls: parameterDecls,
      returnClause: returnClause
    )
  }

  /// print toplevel alias to binded function
  func printToplevelDecl(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    printer.printSeparator(decl.displayName)

    guard let context = makeKotlinBindingPrintContext(for: decl, failureKind: "toplevel") else {
      return
    }

    printKDoc(decl.swiftDecl, in: &printer)

    let argsString = context.cFunction.parameters.map { $0.name! }.joined(separator: ", ")
    printer.printBraceBlock(
      """
      public fun \(context.methodName)(\(context.parameterDecls.joined(separator: ", ")))\(context.returnClause)
      """
    ) { printer in
      printer.print("return \(swiftModuleName).\(context.methodName)(\(argsString))")
    }
    printer.println()
  }

  /// Print kotlin bindings for a single function:
  /// - descriptor object
  /// - downcall wrapper
  func printFunctionDowncallMethods(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    guard let _ = kotlinDecl(for: decl) else {
      return
    }

    printer.printSeparator(decl.displayName)

    printKotlinBindingDescriptorObject(&printer, decl)
    printKotlinBindingWrapperMethod(&printer, decl)
  }

  // MARK: Descriptor object

  /// Print a private Kotlin `object` that holds the FFM's `FunctionDescriptor` (DESC),
  /// resolved pointer to function (MemorySegment ADDR), `MethodHandle`, and a `call()` helper
  func printKotlinBindingDescriptorObject(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    let thunkName = thunkNameRegistry.functionThunkName(decl: decl)
    let kotlinDecl = self.kotlinDecl(for: decl)!
    let cFunction = try! kotlinDecl.loweredSignature.cFunctionDecl(cName: thunkName)

    printKotlinBindingDescriptorObject(&printer, cFunction)
  }

  func printKotlinBindingDescriptorObject(
    _ printer: inout CodePrinter,
    _ cFunc: CFunction
  ) {
    let thunkObjectName = kotlinIdentifier(cFunc.name)

    printer.printBraceBlock(
      """
      /**
       * ```c
       * \(cFunc.description)
       * ```
       */
      private object \(thunkObjectName)
      """
    ) { printer in
      printKotlinFunctionDescriptorDefinition(&printer, cFunc.resultType, cFunc.parameters)
      printer.print(
        """
        @JvmField
        val ADDR: MemorySegment =
          \(self.swiftModuleName).findOrThrow(\(kotlinStringLiteral(cFunc.name)))
        @JvmField
        val HANDLE: MethodHandle = Linker.nativeLinker().downcallHandle(ADDR, DESC)
        """
      )
      printKotlinBindingDowncallMethod(&printer, cFunc)
    }
  }

  /// Print the `FunctionDescriptor` definition in Kotlin syntax.
  func printKotlinFunctionDescriptorDefinition(
    _ printer: inout CodePrinter,
    _ resultType: CType,
    _ parameters: [CParameter]
  ) {
    printer.start("@JvmField\nval DESC: FunctionDescriptor = ")

    let isEmptyParam = parameters.isEmpty
    if resultType.isVoid {
      printer.print("FunctionDescriptor.ofVoid(", isEmptyParam ? .continue : .newLine)
      printer.indent()
    } else {
      printer.print("FunctionDescriptor.of(")
      printer.indent()
      printer.print("/* return type */", .continue)
      printer.print(resultType.foreignValueLayout, .parameterNewlineSeparator(isEmptyParam))
    }

    for (param, isLast) in parameters.withIsLast {
      printer.print("/* \(param.name ?? "_"): */", .continue)
      printer.print(param.type.foreignValueLayout, .parameterNewlineSeparator(isLast))
    }

    printer.outdent()
    printer.print(")")
  }

  /// print the `call()` downcall helper inside a descriptor object
  func printKotlinBindingDowncallMethod(
    _ printer: inout CodePrinter,
    _ cFunction: CFunction
  ) {
    let returnKotlinType = Self.kotlinType(for: cFunction.resultType.javaType)
    let isVoid = cFunction.resultType.isVoid

    var parameterDecls: [String] = []
    var args: [String] = []
    for param in cFunction.parameters {
      let name = param.name!
      let kotlinTy = Self.kotlinType(for: param.type.javaType)
      parameterDecls.append("\(name): \(kotlinTy)")
      args.append(name)
    }
    let parametersString = parameterDecls.joined(separator: ", ")
    let argsString = args.joined(separator: ", ")

    let returnClause = isVoid ? "" : ": \(returnKotlinType)"
    let maybeReturn = isVoid ? "" : "return "
    let returnTypeCastSuffix: String = isVoid ? "" : " as \(returnKotlinType)"

    printer.printBraceBlock(
      """
      @JvmStatic
      fun call(\(parametersString))\(returnClause)
      """
    ) { printer in
      printer.print("\(maybeReturn)HANDLE.invokeExact(\(argsString))\(returnTypeCastSuffix)")
    }
  }


  /// print the public function that calls downcall helper passing given parameters
  /// and adapting them for FFM
  func printKotlinBindingWrapperMethod(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    guard let context = makeKotlinBindingPrintContext(for: decl, failureKind: "wrapper") else {
      return
    }

    printKDoc(decl.swiftDecl, in: &printer)

    printer.printBraceBlock(
      """
      @JvmStatic
      public fun \(context.methodName)(\(context.parameterDecls.joined(separator: ", ")))\(context.returnClause)
      """
    ) { printer in
      printKotlinDowncall(&printer, decl, context.cFunction)
    }
    printer.println()
  }

  /// print downcall body in Kotlin
  func printKotlinDowncall(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc,
    _ cFunction: CFunction
  ) {
    let swiftSignature = decl.functionSignature

    var requiresTemporaryArena = false
    var downcallArguments: [String] = []

    for (idx, param) in swiftSignature.parameters.enumerated() {
      let parameterName = param.parameterName ?? "_\(idx)"
      guard
        let rendered = renderDowncallArgument(
          swiftType: param.type,
          parameterName: parameterName,
          requiresArena: &requiresTemporaryArena
        )
      else {
        log.info("Failed Kotlin downcall translation: '\(decl.swiftDecl.qualifiedNameForDebug)'; unsupported argument type")
        return
      }
      downcallArguments.append(rendered)
    }

    if requiresTemporaryArena {
      printer.print("Arena.ofConfined().use { arena ->")
      printer.indent()
    }

    let thunkName = thunkNameRegistry.functionThunkName(decl: decl)
    let thunkObjectName = kotlinIdentifier(thunkName)

    let downcallExpression = "\(thunkObjectName).call(\(downcallArguments.joined(separator: ", ")))"

    if cFunction.resultType.isVoid {
      printer.print(downcallExpression)
    } else {
      let useTemporaryResult = requiresTemporaryResultValue(for: swiftSignature.result.type)
      let downcallValue: String
      if useTemporaryResult {
        downcallValue = "result"
        printer.print("val \(downcallValue) = \(downcallExpression)")
      } else {
        downcallValue = downcallExpression
      }

      let resultExpr = renderDowncallResult(
        swiftResultType: swiftSignature.result.type,
        loweredResultType: cFunction.resultType,
        downCallExpr: downcallValue
      )
      printer.print("return \(resultExpr)")
    }

    if requiresTemporaryArena {
      printer.outdent()
      printer.print("}")
    }
  }

  private func renderKotlinWrapperParameters(_ swiftSignature: SwiftFunctionSignature) -> [String]? {
    var params: [String] = []
    for (idx, param) in swiftSignature.parameters.enumerated() {
      let name = param.parameterName ?? "_\(idx)"
      guard let kotlinTy = Self.kotlinType(for: param.type) else {
        return nil
      }
      params.append("\(name): \(kotlinTy)")
    }
    return params
  }

  private func renderDowncallArgument(
    swiftType: SwiftType,
    parameterName: String,
    requiresArena: inout Bool
  ) -> String? {
    if (try? CType(cdeclType: swiftType)) != nil {
      return parameterName
    }

    switch swiftType {
    case .nominal(let nominal):
      if nominal.nominalTypeDecl.knownTypeKind == .string {
        requiresArena = true
        return "SwiftRuntime.toCString(\(parameterName), arena)"
      }
      return nil

    case .optional(let wrapped):
      if case .nominal(let nominal) = wrapped,
        nominal.nominalTypeDecl.knownTypeKind == .string
      {
        requiresArena = true
        return "if (\(parameterName) == null) MemorySegment.NULL else SwiftRuntime.toCString(\(parameterName), arena)"
      }

      let arenaArgName = "arena"

      guard let wrappedCType = try? CType(cdeclType: wrapped) else {
        return nil
      }
      requiresArena = true

      let primitiveTypes: [JavaType: String] = [
        .int: "Int", .long: "Long", .double: "Double", .boolean: "Boolean",
        .byte: "Byte", .char: "Character", .short: "Short", .float: "Float",
      ]

      func kotlinOptToJavaOpt(typeName: String, parameterName: String) -> String {
        "if (\(parameterName) == null) Optional\(typeName).empty() else Optional\(typeName).of(\(parameterName))"
      }
      guard let typeName = primitiveTypes[wrappedCType.javaType] else { return nil }
      let kotlinOptParam = kotlinOptToJavaOpt(typeName: typeName, parameterName: parameterName)
      return "SwiftRuntime.toOptionalSegment\(typeName)(\(kotlinOptParam), \(arenaArgName))"

    default:
      return nil
    }
  }

  private func renderDowncallResult(
    swiftResultType: SwiftType,
    loweredResultType: CType,
    downCallExpr: String
  ) -> String {
    if case .nominal(let nominal) = swiftResultType,
      nominal.nominalTypeDecl.knownTypeKind == .string
    {
      return "\(downCallExpr).reinterpret(Long.MAX_VALUE).getString(0)"
    }

    if case .optional(let wrapped) = swiftResultType,
      case .nominal(let nominal) = wrapped,
      nominal.nominalTypeDecl.knownTypeKind == .string
    {
      return "if (\(downCallExpr).address() == 0L) null else \(downCallExpr).reinterpret(Long.MAX_VALUE).getString(0)"
    }

    _ = loweredResultType
    return downCallExpr
  }

  private func requiresTemporaryResultValue(for swiftResultType: SwiftType) -> Bool {
    if case .optional(let wrapped) = swiftResultType,
      case .nominal(let nominal) = wrapped,
      nominal.nominalTypeDecl.knownTypeKind == .string
    {
      return true
    }
    return false
  }

  func printKDoc(_ syntax: some DeclSyntaxProtocol, in printer: inout CodePrinter) {
    var groups = [String]()
    if let documentation = SwiftDocumentationParser.parse(syntax) {
      if let summary = documentation.summary {
        groups.append(summary)
      }
      if let discussion = documentation.discussion {
        let paragraphs = discussion.split(separator: "\n\n")
        for paragraph in paragraphs {
          groups.append("<p>\(paragraph)")
        }
      }
      let annotationLines =
        documentation.parameters.map { "@param \($0.name) \($0.description)" }
        + (documentation.returns.map { ["@return \($0)"] } ?? [])
      if !annotationLines.isEmpty {
        groups.append(annotationLines.joined(separator: "\n"))
      }
    }

    groups.insert(
      """
      Downcall to Swift:
      {@snippet lang=swift :
      \(syntax.signatureString)
      }
      """,
      at: groups.count
    )

    printer.print("/**")
    let oldIndentationText = printer.indentationText
    printer.indentationText += " * "
    for (idx, group) in groups.enumerated() {
      printer.print(group)
      if idx < groups.count - 1 {
        printer.println()
      }
    }
    printer.indentationText = oldIndentationText
    printer.print(" */")
  }

  private func kotlinIdentifier(_ name: String) -> String {
    guard
      name.allSatisfy({ $0 == "_" || $0.isLetter || $0.isNumber })
    else {
      return "`\(name)`"
    }
    return name
  }

  private func kotlinStringLiteral(_ text: String) -> String {
    let escaped = text.replacing("$", with: "\\$")
    return "\"\(escaped)\""
  }
}
