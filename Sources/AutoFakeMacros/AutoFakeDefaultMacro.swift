import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct AutoFakeDefaultMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let variable = declaration.as(VariableDeclSyntax.self),
              let variableName = variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              let returnType = variable.bindings.first?.typeAnnotation?.type.trimmedDescription,
              let attribute = variable.attributes.compactMap({ $0.as(AttributeSyntax.self) })
                  .first(where: { $0.attributeName.trimmedDescription == "AutoFakeDefault" }),
              let argument = attribute.arguments?.as(LabeledExprListSyntax.self)?.first
        else {
            return []
        }

        return [
            """
            static func _autoFakeDefault_\(raw: variableName)() -> \(raw: returnType) {
                return \(raw: argument.expression.trimmedDescription)
            }
            """
        ]
    }
}
