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

struct AnyContext: AppContext {
    
}

class ArchitectureKitTests: XCTestCase {
    
    func testArchitecture(){
        
        let expect = expectation(description: "testArchitecture")
        
        let context = AnyContext()
        let button = UIButton()
        
        func categoriesBinding(state: State) -> AsyncResult<AppContext, Void> {
            return AsyncResult<AppContext, Void>.ask.flatMap { context -> AsyncResult<AppContext, Void> in
                print(state.categories)
                return AsyncResult<AppContext, Void>.pureTT(())
            }
        }
        
        func dummyBinding(state: State) -> AsyncResult<AppContext, Void> {
            return AsyncResult<AppContext, Void>.ask.flatMap { context -> AsyncResult<AppContext, Void> in
                print("Dummy binding")
                return AsyncResult<AppContext, Void>.pureTT(())
            }
        }
        
        func loadCategories() -> AsyncResult<AppContext, Event> {
            let categories = ["dev"]

            return AsyncResult<AppContext, Event>.unfold { _ in
                return Future.unfold { continuation in
                    runInBackground { runInUI in
                        let result = Result<SystemError, Event>.success(Event.categoriesLoaded(Result.success(categories)))
                        runInUI {
                            continuation(result)
                        }
                    }
                }
            }
        }
        
        let initialState = State.empty
        let uiBindings = [categoriesBinding, dummyBinding]
        let feedback = [Feedback.react({_ in loadCategories()}, when: { $0.shouldLoadData})]
        
        
        let userAction = UserAction()
        let system = System.pure(
            initialState: initialState,
            context: context,
            reducer: State.reduce,
            uiBindings: uiBindings,
            userActions: [userAction],
            feedback: feedback
        )
        
        system.run {
            expect.fulfill()
        }
        //Simulate user interaction - Tap button
        userAction.execute(value: 1)
        
        wait(for: [expect], timeout: 10.0)
    }
    
}
