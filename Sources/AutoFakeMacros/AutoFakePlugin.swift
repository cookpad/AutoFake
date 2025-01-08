import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct AutoFakePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AutoFakeMacro.self,
        AutoFakeDefaultMacro.self
    ]
}
