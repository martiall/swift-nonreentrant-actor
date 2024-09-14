@attached(member, names: named($nonreentrant$queue), named(deinit))
@attached(memberAttribute)
public macro NonReentrant() = #externalMacro(module: "NonReentrantMacros", type: "NonReentrantMacro")

@attached(body)
public macro NonReentrantMember() = #externalMacro(module: "NonReentrantMacros", type: "NonReentrantMacro")
