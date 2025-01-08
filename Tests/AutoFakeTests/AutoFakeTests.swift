import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(AutoFakeMacros)
import AutoFakeMacros

let testMacros: [String: Macro.Type] = [
    "AutoFake": AutoFakeMacro.self,
    "AutoFakeDefault": AutoFakeDefaultMacro.self
]
#endif

// swiftlint:disable line_length
final class AutoFakeTests: XCTestCase {
    func testMacro() throws {
        #if canImport(AutoFakeMacros)
        assertMacroExpansion(
            """
            @AutoFake
            struct User {
                let name: String
                let age: Int
                let href: URL
                let createdAt: Date
                let isPremium: Bool
            }
            """,
            expandedSource: """

            struct User {
                let name: String
                let age: Int
                let href: URL
                let createdAt: Date
                let isPremium: Bool

                static func fake(
                    name: String = "", age: Int = 0, href: URL = URL(string: \"https://httpbin.org/get\")!, createdAt: Date = Date(timeIntervalSinceReferenceDate: 0), isPremium: Bool = false
                ) -> Self {
                    Self(
                        name: name, age: age, href: href, createdAt: createdAt, isPremium: isPremium
                    )
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroNestedAutoFake() throws {
        #if canImport(AutoFakeMacros)
        assertMacroExpansion(
            """
            @AutoFake
            struct AnotherStruct {
                let name: String
            }

            @AutoFake
            struct User {
                let anotherStruct: AnotherStruct
            }
            """,
            expandedSource: """

            struct AnotherStruct {
                let name: String

                static func fake(
                    name: String = ""
                ) -> Self {
                    Self(
                        name: name
                    )
                }
            }
            struct User {
                let anotherStruct: AnotherStruct

                static func fake(
                    anotherStruct: AnotherStruct = .fake()
                ) -> Self {
                    Self(
                        anotherStruct: anotherStruct
                    )
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroNestedType() throws {
        #if canImport(AutoFakeMacros)
        assertMacroExpansion(
            """
            @AutoFake
            struct Response {
                @AutoFake
                struct Extra {
                    let body: Body

                    @AutoFake
                    struct Body {
                        let bookmarkIds: [Int]
                    }
                }

                let extra: Response.Extra
            }
            """,
            expandedSource:
            """
            struct Response {
                struct Extra {
                    let body: Body
                    struct Body {
                        let bookmarkIds: [Int]

                        static func fake(
                            bookmarkIds: [Int] = []
                        ) -> Self {
                            Self(
                                bookmarkIds: bookmarkIds
                            )
                        }
                    }

                    static func fake(
                        body: Body = .fake()
                    ) -> Self {
                        Self(
                            body: body
                        )
                    }
                }

                let extra: Response.Extra

                static func fake(
                    extra: Response.Extra = .fake()
                ) -> Self {
                    Self(
                        extra: extra
                    )
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroRawRepresentable() throws {
        #if canImport(AutoFakeMacros)
        assertMacroExpansion(
            """
            @AutoFake
            struct Emoji: RawRepresentable, Codable {
                let rawValue: String
                static let thumbsUp = Emoji(rawValue: "👍")
                static let thumbsDown = Emoji(rawValue: "👎")
            }
            """,
            expandedSource:
            """

            struct Emoji: RawRepresentable, Codable {
                let rawValue: String
                static let thumbsUp = Emoji(rawValue: "👍")
                static let thumbsDown = Emoji(rawValue: "👎")

                static func fake() -> Self {
                    return .thumbsUp
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testIgnoreComment() throws {
        #if canImport(AutoFakeMacros)
        assertMacroExpansion(
            """
            @AutoFake
            struct User {
                let premiumBadgeEnabled: Bool? // PS feature
            }
            """,
            expandedSource:
            """

            struct User {
                let premiumBadgeEnabled: Bool? // PS feature

                static func fake(
                    premiumBadgeEnabled: Bool? = nil
                ) -> Self {
                    Self(
                        premiumBadgeEnabled: premiumBadgeEnabled
                    )
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testIgnoreComputedProperty() throws {
        #if canImport(AutoFakeMacros)
        assertMacroExpansion(
            """
            @AutoFake
            struct User {
                let premiumBadgeEnabled: Bool { // PS feature
                    return false
                }
            }
            """,
            expandedSource:
            """

            struct User {
                let premiumBadgeEnabled: Bool { // PS feature
                    return false
                }

                static func fake(

                ) -> Self {
                    Self(

                    )
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testVariousTypes() throws {
        #if canImport(AutoFakeMacros)
        assertMacroExpansion(
            """
            @AutoFake
            struct User {
                let array: [String] // array
                let dict: [String: String] // dict
                let optional: String? // opt1
                let optional2: Optional<String> // opt2
            }
            """,
            expandedSource:
            """

            struct User {
                let array: [String] // array
                let dict: [String: String] // dict
                let optional: String? // opt1
                let optional2: Optional<String> // opt2

                static func fake(
                    array: [String] = [], dict: [String: String] = [:], optional: String? = nil, optional2: Optional<String> = nil
                ) -> Self {
                    Self(
                        array: array, dict: dict, optional: optional, optional2: optional2
                    )
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testCustomDefaultValue() throws {
        #if canImport(AutoFakeMacros)
        assertMacroExpansion(
            """
            @AutoFake
            struct User {
                @AutoFakeDefault(Set<Int>())
                let set: Set<Int> // aaa
            }
            """,
            expandedSource:
            """

            struct User {
                let set: Set<Int> // aaa

                static func _autoFakeDefault_set() -> Set<Int> {
                    return Set<Int>()
                }

                static func fake(
                    set: Set<Int> = _autoFakeDefault_set()
                ) -> Self {
                    Self(
                        set: set
                    )
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testGrabFirstEnumCase() throws {
        #if canImport(AutoFakeMacros)
        assertMacroExpansion(
            """
            @AutoFake
            enum ComplexEnum {
                static let allCases = [.type1, type2]
                func toString() -> String { String(describing: self) }

                case type1, type2, type3 // aaa
                case type4
            }
            """,
            expandedSource:
            """

            enum ComplexEnum {
                static let allCases = [.type1, type2]
                func toString() -> String { String(describing: self) }

                case type1, type2, type3 // aaa
                case type4

                static func fake() -> Self {
                    return .type1
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testManualInitizer() throws {
        #if canImport(AutoFakeMacros)
        assertMacroExpansion(
            """
            @AutoFake
            struct User: Decodable {
                let name: String
                let age: Int?
                @AutoFakeDefault(Premium.expireIn(Date()))
                let premium: Prmeium

                enum CodingKeys: CodingKey {
                    case name, age, premium
                }

                init(
                    from // aa
                    decoder // aa
                    : Decoder
                ) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.name = try container.decode(String.self, forKey: .name)
                    self.age = try container.decodeIfPresent(Int.self, forKey: .age)
                    self.premium = try container.decode(Premium.self, forKey: .premium)
                }

                // order of arguments are flipped for some reasons
                init(premium: Premium, age: Int, name: String) {
                    self.premium = premium
                    self.age = age
                    self.name = name
                }
            }
            """,
            expandedSource:
            """

            struct User: Decodable {
                let name: String
                let age: Int?
                let premium: Prmeium

                static func _autoFakeDefault_premium() -> Prmeium {
                    return Premium.expireIn(Date())
                }

                enum CodingKeys: CodingKey {
                    case name, age, premium
                }

                init(
                    from // aa
                    decoder // aa
                    : Decoder
                ) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.name = try container.decode(String.self, forKey: .name)
                    self.age = try container.decodeIfPresent(Int.self, forKey: .age)
                    self.premium = try container.decode(Premium.self, forKey: .premium)
                }

                // order of arguments are flipped for some reasons
                init(premium: Premium, age: Int, name: String) {
                    self.premium = premium
                    self.age = age
                    self.name = name
                }

                static func fake(
                    premium: Premium = _autoFakeDefault_premium(), age: Int = 0, name: String = ""
                ) -> Self {
                    Self(
                        premium: premium, age: age, name: name
                    )
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testEnumWithAssociatedValues() throws {
        #if canImport(AutoFakeMacros)
        assertMacroExpansion(
            """
            @AutoFake
            enum EnumWithAssociatedValueInPrimitiveType {
                case string(String), integer(Int)
            }
            """,
            expandedSource:
            """

            enum EnumWithAssociatedValueInPrimitiveType {
                case string(String), integer(Int)

                static func fake() -> Self {
                    return .string("")
                }
            }
            """,
            macros: testMacros
        )

        assertMacroExpansion(
            """
            @AutoFake
            enum EnumWithAssociatedValueInCustomType {
                case user(User) // comment
            }
            """,
            expandedSource:
            """

            enum EnumWithAssociatedValueInCustomType {
                case user(User) // comment

                static func fake() -> Self {
                    return .user(.fake())
                }
            }
            """,
            macros: testMacros
        )

        assertMacroExpansion(
            """
            @AutoFake
            enum EnumWithMultipleAssociatedValues {
                case user(User, Session, String, Int) // comment
            }
            """,
            expandedSource:
            """

            enum EnumWithMultipleAssociatedValues {
                case user(User, Session, String, Int) // comment

                static func fake() -> Self {
                    return .user(.fake(), .fake(), "", 0)
                }
            }
            """,
            macros: testMacros
        )

        assertMacroExpansion(
            """
            @AutoFake
            enum EnumWithLabeledAssociatedValue {
                case user(object: User) // comment
            }
            """,
            expandedSource:
            """

            enum EnumWithLabeledAssociatedValue {
                case user(object: User) // comment

                static func fake() -> Self {
                    return .user(object: .fake())
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
