# Swift2Kotlin Design Notes

## 1) Trade-offs and intentionally cut corners

- Scope kept intentionally small to ship quickly:
  - The generator supports the "happy path" for FFM calls: primitives, C-lowerable values, `String`, and some optionals.

- Kotlin output reuses the Java FFM lowering pipeline:
  - Swift thunk emission is delegated to `FFMSwift2JavaGenerator`.
  - Kotlin then wraps those generated C thunk signatures.
  - This avoids reimplementing lowering logic, but it also inherits Java-centric things

- Type mapping is intentionally simple:
  - `kotlinType(for swiftType:)` covers basic types
  - Optional support is only implemented for specific primitive cases and optional strings in argument/result lowering

- Async/throwing metadata is currently captured but unused:
  - `KotlinFunctionSignature` stores `isAsync` and `isThrowing` but this information is not used in code generation

- Test strategy focuses on generated text shape:
  - I wrote tests that verify generated text shape just like for other targets
  - My tests lack verifying that genererated code is executable


## 2) What an ideal or more complete solution would look like

- Full Swift -> Kotlin type model:
  - Explicit mapping coverage for tuples, arrays, structs/enums, generics, optionals, and user-defined nominal types.
  - Directly pass semantic metadata from Swift to Kotlin.

- First-class async and error bridging:
  - Generate Kotlin `suspend` wrappers for Swift async functions.
  - Bridge Swift throwing functions to Kotlin exceptions/result wrappers with consistent ABI contracts.

- An AST-based DSL for generating Kotlin code instead of imperative raw string printing via `CodePrinter`.

- Removed duplication of FFM setup for function calls

- Better tests:
  - Tests that verify not just generated code text, but also execute it to validate FFM correctness.
  - Tests that run on 32bit and 64bit archs
  
- Kotlin MultiPlatform support:
  - Verify whether the solution works with Kotlin Multiplatform and fix gaps if it does not

## 3) What I should do next if I had more time

1. Add integration tests that actually execute code generated from the bindings

2. Implement translation for user-defined types

3. Pass async/throwing and related metadata from Swift to Kotlin so the Kotlin API is as close as possible to the original Swift API

4. Translate code from Swift directly to Kotlin without Java in between, OR introduce an intermediate representation (Swift -> 'Swift-JVM IR' -> Java | Kotlin).

5. Implement an AST-based Kotlin DSL instead of raw string printing
