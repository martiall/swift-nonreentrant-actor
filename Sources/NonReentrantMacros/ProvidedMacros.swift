import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct NonRentrantMacros: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        NonReentrantMacro.self,
    ]
}
