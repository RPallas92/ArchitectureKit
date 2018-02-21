//
//  ArchitectureKitTests.swift
//  ArchitectureKitTests
//
//  Created by Pallas, Ricardo on 12/14/17.
//  Copyright © 2017 Pallas, Ricardo. All rights reserved.
//

import XCTest
import ArchitectureKit
import FunctionalKit
import UIKit

fileprivate typealias Function = () -> ()
fileprivate typealias Completable = (@escaping Function) -> ()

fileprivate func runInBackground(_ asyncCode: @escaping(@escaping Completable)->()) {
    DispatchQueue.global(qos: .background).async {
        asyncCode { inMainThread in
            DispatchQueue.main.async {
                inMainThread()
            }
        }
    }
}

enum SystemError: Error {
    case genericError
}

enum Event {
    case loadCategories
    case categoriesLoaded(Result<SystemError, [String]>)
}

struct AppContext {
    
}

struct State {
    var categories: [String]
    var shouldLoadData = false
    
    static var empty = State(categories: [], shouldLoadData: false)
    static func reduce(state: State, event: Event) -> State {
        switch event {
        case .loadCategories:
            var newState = state
            newState.shouldLoadData = true
            newState.categories = []
            return newState
        case .categoriesLoaded(let categoriesResult):
            var newState = state
            newState.shouldLoadData = false
            newState.categories = categoriesResult.tryRight!
            return newState
        }
    }
}

class ArchitectureKitTests: XCTestCase {
    
    func testArchitecture(){
        
        let expect = expectation(description: "testArchitecture")
        
        typealias TestSystem = System<State,Event,SystemError, AppContext>
        
        let context = AppContext()
        let button = UIButton()
        
        func categoriesBinding(state: State) {
            print(state.categories)
        }
        
        func dummyBinding(state: State) {
            print("Dummy binding")
        }
        
        func loadCategories() -> AsyncResult<AppContext, Event, SystemError> {
            let categories = ["dev"]
            return AsyncResult<AppContext, Event, SystemError>.unfoldTT { _, continuation in
                runInBackground { runInUI in
                    let event = Event.categoriesLoaded(Result.success(categories))
                    let result:Result<SystemError, Event> = Result.success(event)
                    runInUI {
                        continuation(result)
                    }
                }
            }
        }
        
        let initialState = State.empty
        let uiBindings = [categoriesBinding, dummyBinding]
        let feedback = [
            Feedback<State, Event, SystemError, AppContext>.react({_ in loadCategories()}, when: { $0.shouldLoadData})
        ]
        
        let action = CustomAction<State, Event, SystemError, AppContext>(trigger: Event.loadCategories)
        let system = TestSystem.pure(
            initialState: initialState,
            context: context,
            reducer: State.reduce,
            uiBindings: uiBindings,
            actions: [action],
            feedback: feedback
        )
        
        system.addLoopCallback {
            expect.fulfill()
        }
        
        //Simulate user interaction - Tap button
        action.execute()
        wait(for: [expect], timeout: 10.0)
    }
    
}
