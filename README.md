# ArchitectureKit


The simplest architecture for [FunctionalKit](https://github.com/facile-it/FunctionalKit)  
  Inspired by [RxFeedback](https://github.com/NoTests/RxFeedback.swift), but it uses Monads (from FunctionalKit) instead of RxSwift

<img src="https://github.com/kzaher/rxswiftcontent/raw/master/RxFeedback.png" width="502px" />

```swift
    static func pure(
        initialState: State,
        context: Context,
        reducer: @escaping (State, Event) -> State,
        uiBindings: [(State) -> ()],
        userActions: [SystemUserAction],
        feedback: [SystemFeedback]
        ) -> System {
```

# Why

* Straightforward
    * if it's state -> State
    * if it's a way to modify state -> Event
    * it it's an effect -> encode it into part of state and then design a feedback loop
* Declarative
    * System behavior is first declaratively specified and effects begin after subscribe is called => Compile time proof there are no "unhandled states"
* Debugging is easier
    * A lot of logic is just normal pure function that can be debugged using Xcode debugger, or just printing the commands.

* Can be applied on any level
    * [Entire system](https://kafka.apache.org/documentation/)
    * application (state is stored inside a database, CoreData, Firebase, Realm)
    * view controller (state is stored inside `system` operator)
    * inside feedback loop (another `system` operator inside feedback loop)
* Works awesome with dependency injection
* Testing
    * Reducer is a pure function, just call it and assert results
    * In case effects are being tested -> Expectations
* Can model circular dependencies
* Completely separates business logic from effects.
    * Business logic can be transpiled between platforms (ShiftJS, C++, J2ObjC)
