import NonReentrant
import Foundation

@NonReentrant
actor MyActor {
    func throwsReturn() async throws -> String {
        print("Start \(#function)")
        try await Task.sleep(for: .seconds(1))
        print("End \(#function)")
        return "Returned \(#function)"
    }
    func dontThrowsReturn() async -> String {
        print("Start \(#function)")
        try? await Task.sleep(for: .seconds(1))
        print("End \(#function)")
        return "Returned \(#function)"
    }
    func throwsDontReturn() async throws {
        print("Start \(#function)")
        try await Task.sleep(for: .seconds(1))
        print("End \(#function)")
    }
    func dontThrowsDontReturn() async {
        print("Start \(#function)")
        try? await Task.sleep(for: .seconds(1))
        print("End \(#function)")
    }
}

@NonReentrant
actor MyActorWithDeinit {
    deinit {
        print("I have a deinit")
    }
    func throwsReturn() async throws -> String {
        print("Start \(#function)")
        try await Task.sleep(for: .seconds(1))
        print("End \(#function)")
        return "Returned \(#function)"
    }
    func dontThrowsReturn() async -> String {
        print("Start \(#function)")
        try? await Task.sleep(for: .seconds(1))
        print("End \(#function)")
        return "Returned \(#function)"
    }
    func throwsDontReturn() async throws {
        print("Start \(#function)")
        try await Task.sleep(for: .seconds(1))
        print("End \(#function)")
    }
    func dontThrowsDontReturn() async {
        print("Start \(#function)")
        try? await Task.sleep(for: .seconds(1))
        print("End \(#function)")
    }
}

do {
    let a = MyActor()
    
    await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            print(try await a.throwsReturn())
        }
        group.addTask {
            try await a.throwsDontReturn()
        }
        group.addTask {
            print(await a.dontThrowsReturn())
        }
        group.addTask {
            await a.dontThrowsDontReturn()
        }
    }
}
do {
    let b = MyActorWithDeinit()
    
    await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            print(try await b.throwsReturn())
        }
        group.addTask {
            try await b.throwsDontReturn()
        }
        group.addTask {
            print(await b.dontThrowsReturn())
        }
        group.addTask {
            await b.dontThrowsDontReturn()
        }
    }
}
print("END")
