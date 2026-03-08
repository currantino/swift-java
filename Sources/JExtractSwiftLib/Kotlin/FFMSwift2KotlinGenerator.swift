import SwiftJavaConfigurationShared
import SwiftJavaJNICore
import SwiftSyntax
import SwiftSyntaxBuilder

import struct Foundation.URL

package class FFMSwift2KotlinGenerator: Swift2JavaGenerator {

    let config: Configuration
    let translator: Swift2JavaTranslator
    let javaPackage: String
    let swiftOutputDirectory: URL
    let javaOutputDirectory: URL
    
    package init(
        config: Configuration,
        translator: Swift2JavaTranslator,
        javaPackage: String,
        swiftOutputDirectory: URL,
        javaOutputDirectory: URL  
    ) {
        self.config = config
        self.translator = translator
        self.javaPackage = javaPackage
        self.swiftOutputDirectory = swiftOutputDirectory
        self.javaOutputDirectory = javaOutputDirectory
    }
  func generate() throws {
      fatalError("swift 2 java not implemented yet")
  }
}
