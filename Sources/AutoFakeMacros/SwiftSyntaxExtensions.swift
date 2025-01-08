import SwiftSyntax
import SwiftSyntaxMacros

extension VariableDeclSyntax {
    var isStaticProperty: Bool {
        modifiers.contains(where: { $0.name.text == "static" })
    }

    /// Determine whether this variable has the syntax of a stored property.
    ///
    /// This syntactic check cannot account for semantic adjustments due to,
    /// e.g., accessor macros or property wrappers.
    var isStoredProperty: Bool {
        if bindings.count != 1 {
            return false
        }

        let binding = bindings.first!
        switch binding.accessorBlock?.accessors {
        case .none:
            return true

        case .accessors(let accessors):
            for accessor in accessors {
                switch accessor.accessorSpecifier.tokenKind {
                case .keyword(.willSet), .keyword(.didSet):
                    // Observers can occur on a stored property.
                    break

                default:
                    // Other accessors make it a computed property.
                    return false
                }
            }

            return true

        case .getter:
            return false
        }
    }

    var name: String? {
        guard let firstBiding = bindings.first else { return nil }
        return firstBiding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
    }

    func destruct() -> (name: String, type: TypeSyntax?)? {
        guard let firstBiding = bindings.first,
              let name = firstBiding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
            return nil
        }
        let annotatedType = firstBiding.typeAnnotation?.type
        return (name: name, type: annotatedType)
    }
}

extension DeclGroupSyntax {
    var initializers: [InitializerDeclSyntax] {
        memberBlock.members.compactMap { $0.decl.as(InitializerDeclSyntax.self) }
    }

    func getTypeName() throws -> String {
        guard let typeName: String =
                self.as(StructDeclSyntax.self)?.name.text ??
                self.as(ClassDeclSyntax.self)?.name.text ??
                self.as(ActorDeclSyntax.self)?.name.text ??
                self.as(EnumDeclSyntax.self)?.name.text else {
            throw MacroExpansionErrorMessage("Unsupported type declaration \(self)")
        }
        return typeName
    }

    /// Enumerate the stored properties that syntactically occur in this
    /// declaration.
    func storedProperties() -> [VariableDeclSyntax] {
        return memberBlock.members.compactMap { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  variable.isStoredProperty
            else {
                return nil
            }

            return variable
        }
    }
}

extension EnumDeclSyntax {
    /// Get the list of enum cases
    var enumCases: [EnumCaseDeclSyntax] {
        let enumCaseDeclList = memberBlock.members.filter {
            $0.decl.kind == .enumCaseDecl
        }
        return enumCaseDeclList.compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
    }

    /// Get enum case elements. Notes that a enum case syntax can have multiple elements; e.g. `case a, b, c`
    var firstEnumCase: EnumCaseElementListSyntax? {
        guard let firstEnumCaseDecl = enumCases.first else {
            return nil
        }
        return firstEnumCaseDecl.elements
    }
}

extension InitializerDeclSyntax {
    /// Check if an initializer is meant to conform Decodable protocol
    var isDecodableInitializer: Bool {
        guard let argument = signature.parameterClause.parameters.first,
           argument.firstName.trimmedDescription == "from",
           argument.secondName?.trimmedDescription == "decoder",
           argument.type.trimmedDescription == "Decoder" else {
            return false
        }
        return true
    }
}

extension StructDeclSyntax {
    var inheritedTypes: [String] {
        guard let inheritedTypes = inheritanceClause?.inheritedTypes else {
            return []
        }

        return inheritedTypes.compactMap { $0.type.as(IdentifierTypeSyntax.self)?.name.text }

    }
}
