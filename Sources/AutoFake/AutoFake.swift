@attached(member, names: arbitrary)
public macro AutoFake() = #externalMacro(module: "AutoFakeMacros", type: "AutoFakeMacro")

@attached(peer, names: prefixed(_autoFakeDefault_))
public macro AutoFakeDefault<T>(_ value: T) = #externalMacro(module: "AutoFakeMacros", type: "AutoFakeDefaultMacro")
