import XCTest
import SwiftSyntaxMacrosTestSupport
@testable import NonReentrantMacros

class NonRentrantMacrosTests: XCTestCase {
    func testParentNotAnActor() {
        assertMacroExpansion(
"""
class MyActor {
    @NonReentrantMember
    func test() async {
    }
}
""",
        expandedSource: """
class MyActor {
    func test() async {
    }
}
""",
            diagnostics: [
                .init(message: "notAnActor", line: 1, column: 1),
                .init(message: "parentMustBeAnNonReentrantActor", line: 2, column: 5)
            ],
            macros: [
                "NonReentrant" : NonReentrantMacro.self,
                "NonReentrantMember" : NonReentrantMacro.self
            ],
            applyFixIts: [],
            fixedSource: nil
        )
    }
    
    func testParentNotNonReentrantActor() {
        assertMacroExpansion(
"""
actor MyActor {
    @NonReentrantMember
    func test() async {
    }
}
""",
        expandedSource: """
actor MyActor {
    func test() async {
    }
}
""",
            diagnostics: [
                .init(message: "notReentrantActor", line: 1, column: 1),
                .init(message: "parentMustBeAnNonReentrantActor", line: 2, column: 5)
            ],
            macros: [
                "NonReentrant" : NonReentrantMacro.self,
                "NonReentrantMember" : NonReentrantMacro.self
            ],
            applyFixIts: [],
            fixedSource: nil
        )
    }
    
    func testDeinitGeneration() {
        assertMacroExpansion(
"""
@NonReentrant
actor MyActor {
}
""",
        expandedSource: """
actor MyActor {

    deinit {
        $nonreentrant$queue.task.cancel()
    }

    private let $nonreentrant$queue: (
        continuation: AsyncStream<@Sendable () async -> Void>.Continuation,
        task: Task<Void, Never>
    ) = {
        let (stream, cont) = AsyncStream<@Sendable () async -> Void>.makeStream()
        return (
            continuation: cont,
            task: Task {
                for await fn in stream {
                    await fn()
                }
            }
        )
    }()
}
""",
            diagnostics: [],
            macros: [
                "NonReentrant" : NonReentrantMacro.self,
                "NonReentrantMember" : NonReentrantMacro.self
            ],
            applyFixIts: [],
            fixedSource: nil
        )
    }

    func testNonRentrantMacrosTests() {
        assertMacroExpansion(
"""
@NonReentrant
actor MyActor {
    func throwsReturn() async throws -> String {
        "Ret"
    }
    func dontThrowsReturn() async -> String {
        "Ret"
    }
    func throwsDontReturn() async throws {
        print("")
    }
    func dontThrowsDontReturn() async {
        print("")
    }

    deinit {
        print("deinit")
    }
}
""",
        expandedSource: """
actor MyActor {
    func throwsReturn() async throws -> String {
        try await withUnsafeThrowingContinuation { continuation in
            $nonreentrant$queue.continuation.yield({
                do {
                    continuation.resume(returning: try await {
                        "Ret"
                    }())
                } catch {
                    continuation.resume(throwing: error)
                }
            })
        }
    }
    func dontThrowsReturn() async -> String {
        await withUnsafeContinuation { continuation in
            $nonreentrant$queue.continuation.yield({
                continuation.resume(returning: await {
                    "Ret"
                }())
            })
        }
    }
    func throwsDontReturn() async throws {
        try await withUnsafeThrowingContinuation { continuation in
            $nonreentrant$queue.continuation.yield({
                do {
                    try await {
                        print("")
                    }()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            })
        }
    }
    func dontThrowsDontReturn() async {
        await withUnsafeContinuation { continuation in
            $nonreentrant$queue.continuation.yield({
                await {
                    print("")
                }()
                continuation.resume()
            })
        }
    }

    deinit {
        print("deinit")
        $nonreentrant$queue.task.cancel()
    }

    private let $nonreentrant$queue: (
        continuation: AsyncStream<@Sendable () async -> Void>.Continuation,
        task: Task<Void, Never>
    ) = {
        let (stream, cont) = AsyncStream<@Sendable () async -> Void>.makeStream()
        return (
            continuation: cont,
            task: Task {
                for await fn in stream {
                    await fn()
                }
            }
        )
    }()
}
""",
            diagnostics: [],
            macros: [
                "NonReentrant" : NonReentrantMacro.self,
                "NonReentrantMember" : NonReentrantMacro.self
            ],
            applyFixIts: [],
            fixedSource: nil
        )
    }
}
