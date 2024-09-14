# Swift Non-Reentrant actor macro

Following a discussion on the Swift Forum [Making actor non reentrant](https://forums.swift.org/t/making-actor-non-reentrant/73131) some ideas were proposed to workaround this limitation.
One being to queue all calls to an AsyncStream and execute them serially.

Would it be possible to implement this pattern using the newly added [Function Body Macro](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0415-function-body-macros.md) ?

This is not well tested, or even assessed to be correct. Use this at your own risk.

Feedbacks are more than welcome.
