# ArchitectureKit
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) ![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Linux-333333.svg)

The simplest architecture for [FunctionalKit](https://github.com/facile-it/FunctionalKit)  
  Inspired by [RxFeedback](https://github.com/NoTests/RxFeedback.swift), but it uses Monads (from FunctionalKit) instead of RxSwift, and allows dependency injection out of the box,

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

## Motivation
This architectural approach, fits on the View layer of Clean Architecture.  
It is an alternative to Model-View-Presenter or Model-View-ViewModel, and it is strongly inspired by Redux.

The idea is to constrain the changes to view state in order to enforce correctness. Changes to state are explicity documented by Events and a reducer (pure) function. This approach also allows testing presentation logic with easy (it also includes a mechanism to inject dependencies, such views, API Clients, etc.)



## Installation
ArchitectureKit only contains FunctionalKit dependency

These are currently the supported options:

### [Carthage](https://github.com/Carthage/Carthage)

Add this to `Cartfile`

```
github "RPallas92/ArchitectureKit" "master"
```

```bash
$ carthage update
```


## Quick example
The purpose of this example is explain how to use FunctionalKit


## Rule of thumb

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

## License

```
Copyright 2017 - 2018 Ricardo Pallás Román

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

```

## Author
[Ricardo Pallás](https://www.linkedin.com/in/rpallas/)
