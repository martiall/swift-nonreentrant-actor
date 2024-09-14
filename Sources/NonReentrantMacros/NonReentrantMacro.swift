import SwiftCompilerPlugin
import SwiftSyntaxMacros
import SwiftSyntax

struct NonReentrantMacro: MemberMacro, BodyMacro, MemberAttributeMacro {
    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        do {
            try Self.checkNonReentrantActor(declaration: declaration)
        } catch {
            context.addDiagnostics(from: error, node: declaration)
            throw error
        }
        
        let nonreentrantAttributes: [AttributeSyntax] = ["@NonReentrantMember"]
        return switch member.kind {
        case .accessorDeclList:
            nonreentrantAttributes
        case .accessorDecl:
            nonreentrantAttributes
        case .functionDecl:
            if member.as(FunctionDeclSyntax.self)?.signature.effectSpecifiers?.asyncSpecifier != nil {
                nonreentrantAttributes
            } else {
                []
            }
        case .deinitializerDecl:
            nonreentrantAttributes
        case .subscriptDecl:
            nonreentrantAttributes
        default:
            []
        }
    }
    static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        do {
            try Self.checkNonReentrantActor(declaration: declaration)
        } catch {
            context.addDiagnostics(from: NonReentrantMacroError.parentMustBeAnNonReentrantActor, node: declaration)
            throw NonReentrantMacroError.parentMustBeAnNonReentrantActor
        }
        
        var deinitGeneration: [DeclSyntax] = []
        if declaration.memberBlock.members.first(where: { $0.decl.kind == .deinitializerDecl }) == nil {
            deinitGeneration = [
                """
            deinit {
                $nonreentrant$queue.task.cancel()
            }
            """
            ]
        }
        
        return deinitGeneration + [
            """
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
            """
        ]
    }
    
    enum NonReentrantMacroError: Error {
        case notAnActor
        case notReentrantActor
        case bodyMandatory
        case mustBeAsync
        case parentMustBeAnNonReentrantActor
    }
    
    static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        //TODO: Check that we are in an Actor with @NonReentrantActor macro attached
        guard context.lexicalContext.count == 1 else
        {
            throw NonReentrantMacroError.parentMustBeAnNonReentrantActor
        }
        let parent = context.lexicalContext[0]
        do {
            try Self.checkNonReentrantActor(declaration: parent)
        } catch {
            context.addDiagnostics(from: error, node: parent)
            throw NonReentrantMacroError.parentMustBeAnNonReentrantActor
        }
        guard let body = declaration.body else {
            context.addDiagnostics(
                from: NonReentrantMacroError.bodyMandatory,
                node: declaration
            )
            throw NonReentrantMacroError.bodyMandatory
        }
        
        if declaration.kind == .deinitializerDecl {
            return [
                "\(body.statements.trimmed)",
                "$nonreentrant$queue.task.cancel()"
            ]
        }
        
        guard let method = declaration.as(FunctionDeclSyntax.self) else {
            fatalError()
        }
        
        let isAsync = method.signature.effectSpecifiers?.asyncSpecifier != nil
        if isAsync == false {
            context.addDiagnostics(from: NonReentrantMacroError.mustBeAsync, node: declaration)
            throw NonReentrantMacroError.mustBeAsync
        }
        
        let isThrowing = method.signature.effectSpecifiers?.throwsClause != nil
        let isReturning = method.signature.returnClause != nil
        let bodyStatements = CodeBlockItemListSyntax(body.statements.map {
            var item = $0.trimmed
            item.leadingTrivia = Trivia(pieces: item.leadingTrivia
                .filter({ !$0.isNewline })
            )
            return item
        })
        return switch (isThrowing, isReturning) {
        case (true, true):
            [
            """
try await withUnsafeThrowingContinuation { continuation in
    $nonreentrant$queue.continuation.yield({
        do {
            continuation.resume(returning: try await {
                \(bodyStatements)
            }())
        } catch {
            continuation.resume(throwing: error)
        }
    })
}
"""
            ]
        case (true, false):
            [
            """
try await withUnsafeThrowingContinuation { continuation in
    $nonreentrant$queue.continuation.yield({
        do {
            try await {
                \(bodyStatements)
            }()
            continuation.resume()
        } catch {
            continuation.resume(throwing: error)
        }
    })
}
"""
            ]
        case (false, true):
            [
            """
await withUnsafeContinuation { continuation in
    $nonreentrant$queue.continuation.yield({
        continuation.resume(returning: await {
            \(bodyStatements)
        }())
    })
}
"""
            ]
        case (false, false):
            [
            """
await withUnsafeContinuation { continuation in
    $nonreentrant$queue.continuation.yield({
        await {
            \(bodyStatements)
        }()
        continuation.resume()
    })
}
"""
            ]
        }
    }
    
    private static func checkNonReentrantActor(declaration: some SyntaxProtocol) throws {
        guard declaration.kind == .actorDecl else {
            throw NonReentrantMacroError.notAnActor
        }
        
        let actor = declaration.cast(ActorDeclSyntax.self)
        guard actor.attributes.first(where: { "\($0.cast(AttributeSyntax.self).attributeName)" == "NonReentrant" }) != nil else {
            throw NonReentrantMacroError.notReentrantActor
        }
    }
}
