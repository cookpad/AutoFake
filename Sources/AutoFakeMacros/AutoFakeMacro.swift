import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct AutoFakeMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Pick up the first case from an enum
        if let enumDecl = declaration.as(EnumDeclSyntax.self),
           let expansion = expandEnum(declaration: enumDecl) {
            return expansion
        }

        // Pick up the first static let value from a struct conforming to RawRepresentable working like enum
        if let structDecl = declaration.as(StructDeclSyntax.self),
           let expansion = expandRawRepresentableStruct(declaration: structDecl) {
            return expansion
        }

        // Else

        // Scan all the properties to check if one has @AutoFakeDefault
        let declarationContext = try scanDeclaration(declaration)

        // When an initializer is implemented manually
        if let expanion = expandWithInitializer(declaration: declaration, with: declarationContext) {
            return expanion
        }

        // Otherwise, go through all of the stored properties and use synthesized memberwise initializer
        return expandWithPropertyList(declaration: declaration, with: declarationContext)
    }
}

extension AutoFakeMacro {
    private static func expandEnum(declaration: EnumDeclSyntax) -> [DeclSyntax]? {
        guard let firstEnumCaseElement = declaration.firstEnumCase?.first else {
            return nil
        }

        var associatedValues: [(type: TypeSyntax, label: String?)] = []
        if let parameters = firstEnumCaseElement.parameterClause?.parameters {
            for parameter in parameters {
                associatedValues.append((parameter.type, parameter.firstName?.identifier?.name))
            }
        }
        let associatedValuesString = if associatedValues.isEmpty {
            ""
        } else {
             """
             (\(
                 associatedValues.map { associatedValue in
                     if let label = associatedValue.label {
                         let prop = PropertyTypeInfo.from(label, in: associatedValue.type, hasAutoFakeDefault: false)
                         return "\(label): \(defaultValue(for: prop))"
                     } else {
                         let prop = PropertyTypeInfo.from("NONE", in: associatedValue.type, hasAutoFakeDefault: false)
                         return "\(defaultValue(for: prop))"
                     }
                 }.joined(separator: ",")
             ))
             """
        }
        return [
             """

             static func fake() -> Self {
                 return .\(raw: firstEnumCaseElement.name.text)\(raw: associatedValuesString)
             }
             """
        ]
    }

    private static func expandRawRepresentableStruct(declaration: StructDeclSyntax) -> [DeclSyntax]? {
        guard declaration.inheritedTypes.contains("RawRepresentable") else {
            return nil
        }

        let storedProperties = declaration.storedProperties()
        guard let staticVariable = storedProperties.first(where: { $0.isStaticProperty }),
              let name = staticVariable.name else {
            return nil
        }

        // pick up first static val
        return [
            """
            static func fake() -> Self {
                return .\(raw: name)
            }
            """
        ]
    }

    private static func scanDeclaration(_ declaration: DeclGroupSyntax) throws -> DeclarationContext {
        var isDefaultAvailable: [String: Bool] = [:]
        for storedProperty in declaration.storedProperties() {
            if let propertyName = storedProperty.bindings.first?.pattern.trimmedDescription {
                let attributes = storedProperty.attributes.compactMap({ $0.as(AttributeSyntax.self) })
                let isAvailable = attributes.contains(where: { $0.attributeName.trimmedDescription == "AutoFakeDefault" })
                isDefaultAvailable[propertyName] = isAvailable
            }
        }
        return DeclarationContext(
            typeName: try declaration.getTypeName(),
            isDefaultAvailable: isDefaultAvailable
        )
    }

    private static func expandWithInitializer(declaration: DeclGroupSyntax, with context: DeclarationContext) -> [DeclSyntax]? {
        // Ignore Decodable's initializer
        guard let initializer = declaration.initializers.first(where: { !$0.isDecodableInitializer }) else {
            return nil
        }

        var props: [PropertyTypeInfo] = []
        for argument in initializer.signature.parameterClause.parameters {
            let parameterName = argument.firstName.trimmedDescription
            let parameterType = argument.type
            let prop = PropertyTypeInfo.from(
                parameterName,
                in: parameterType,
                hasAutoFakeDefault: context.isDefaultAvailable[parameterName] ?? false
            )
            props.append(prop)
        }

        let arguments = props.map { AutoFakeArgument(name: $0.name, typeName: $0.type, defaultValue: defaultValue(for: $0)) }
        return [
            template(type: .init(name: context.typeName, arguments: arguments))
        ]
    }

    private static func expandWithPropertyList(declaration: DeclGroupSyntax, with context: DeclarationContext) -> [DeclSyntax] {
        var props: [PropertyTypeInfo] = []
        for property in declaration.storedProperties() {
            // Ignore static property and computed property
            guard !property.isStaticProperty,
                  property.isStoredProperty else {
                continue
            }

            // Destruct stored property declaration into name and type
            guard let pair = property.destruct(),
                  let type = pair.type else {
                continue
            }
            let name = pair.name
            let prop = PropertyTypeInfo.from(name, in: type, hasAutoFakeDefault: context.isDefaultAvailable[name] ?? false)
            props.append(prop)
        }

        let arguments = props.map { AutoFakeArgument(name: $0.name, typeName: $0.type, defaultValue: defaultValue(for: $0)) }
        return [
            template(type: .init(name: context.typeName, arguments: arguments))
        ]
    }

    private static func template(type: AutoFakeType) -> DeclSyntax {
        let arguments = type.arguments.map { "\($0.name): \($0.typeName) = \($0.defaultValue)" }.joined(separator: ",")
        let parameters = type.arguments.map { "\($0.name.replacingOccurrences(of: "`", with: "")): \($0.name)" }.joined(
            separator: ","
        )

        return (
            """

            static func fake(
            \(raw: arguments)
            ) -> Self {
                Self(
            \(raw: parameters)
                )
            }
            """
        )
    }

    private static func defaultValue(for prop: PropertyTypeInfo) -> String {
        if prop.hasAutoFakeDefault {
            return "_autoFakeDefault_\(prop.name)()"
        }

        if prop.isOptional {
            return "nil"
        }

        if prop.isArray {
            return "[]"
        }

        if prop.isDictionary {
            return "[:]"
        }

        switch prop.type {
        case "String":
            return "\"\""
        case "Date":
            return "Date(timeIntervalSinceReferenceDate: 0)"
        case "Bool":
            return "false"
        case "URL":
            return "URL(string: \"https://httpbin.org/get\")!"
        case "Int":
            return "0"
        case "Double", "Float", "CGFloat":
            return "0.0"
        case "CGRect", "CGSize", "CGPoint":
            return ".zero"
        default:
            return ".fake()"
        }
    }

}

final class DeclarationContext {
    let typeName: String
    let isDefaultAvailable: [String: Bool]

    init(typeName: String, isDefaultAvailable: [String: Bool]) {
        self.typeName = typeName
        self.isDefaultAvailable = isDefaultAvailable
    }
}

struct AutoFakeArgument {
    let name: String
    let typeName: String
    let defaultValue: String
}

struct AutoFakeType {
    let name: String
    let arguments: [AutoFakeArgument]
}

struct PropertyTypeInfo: Equatable {
    let name: String
    let type: String
    let isOptional: Bool
    let isArray: Bool
    let isDictionary: Bool
    let hasAutoFakeDefault: Bool

    init(
        name: String,
        type: String,
        isOptional: Bool = false,
        isArray: Bool = false,
        isDictionary: Bool = false,
        hasAutoFakeDefault: Bool = false
    ) {
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.isArray = isArray
        self.isDictionary = isDictionary
        self.hasAutoFakeDefault = hasAutoFakeDefault
    }

    static func from(_ name: String, in type: TypeSyntax, hasAutoFakeDefault: Bool) -> PropertyTypeInfo {
        switch type.kind {
        case .optionalType:
            return PropertyTypeInfo(
                name: name,
                type: type.as(OptionalTypeSyntax.self)!.trimmedDescription,
                isOptional: true,
                hasAutoFakeDefault: hasAutoFakeDefault
            )
        case .identifierType:
            let isOptional = type.as(IdentifierTypeSyntax.self)!.name.text == "Optional"
            return PropertyTypeInfo(
                name: name,
                type: type.trimmedDescription,
                isOptional: isOptional,
                hasAutoFakeDefault: hasAutoFakeDefault
            )
        case .arrayType:
            return PropertyTypeInfo(
                name: name,
                type: type.trimmedDescription,
                isArray: true,
                hasAutoFakeDefault: hasAutoFakeDefault
            )
        case .dictionaryType:
            return PropertyTypeInfo(
                name: name,
                type: type.trimmedDescription,
                isDictionary: true,
                hasAutoFakeDefault: hasAutoFakeDefault
            )
        default:
            return PropertyTypeInfo(
                name: name,
                type: type.trimmedDescription,
                hasAutoFakeDefault: hasAutoFakeDefault
            )
        }
    }
}
