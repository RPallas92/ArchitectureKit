//
//  System.swift
//  FunctionalSwiftArchitectureTests
//
//  Created by Pallas, Ricardo on 12/14/17.
//  Copyright © 2017 Pallas, Ricardo. All rights reserved.
//

import Foundation

protocol AppContext {
    
}

public struct Feedback {
    var condition: (State) -> (Bool)
    var action: (State) -> AsyncResult<AppContext, Event>
    
    static func react(_ action: @escaping (State) -> AsyncResult<AppContext, Event>, when condition: @escaping (State) -> (Bool)) -> Feedback {
        return Feedback(condition: condition, action: action)
    }
}

class System {
    static var doNothing = AsyncResult<AppContext,Event>.pureTT(Event.doNothing)
    
    var eventQueue = [AsyncResult<AppContext,Event>]()
    var callback: (() -> ())? = nil
    
    var initialState: State
    var context: AppContext
    var reducer: (State, Event) -> State
    var uiBindings: [(State) -> AsyncResult<AppContext, Void>]
    var userActions: [UserAction]
    var feedback: [Feedback]
    
    private init(
        initialState: State,
        context: AppContext,
        reducer: @escaping (State, Event) -> State,
        uiBindings: [(State) -> AsyncResult<AppContext, Void>],
        userActions: [UserAction],
        feedback: [Feedback]
        ) {
        
        self.initialState = initialState
        self.context = context
        self.reducer = reducer
        self.uiBindings = uiBindings
        self.userActions = userActions
        self.feedback = feedback
    }
    static func pure(
        initialState: State,
        context: AppContext,
        reducer: @escaping (State, Event) -> State,
        uiBindings: [(State) -> AsyncResult<AppContext, Void>],
        userActions: [UserAction],
        feedback: [Feedback]
        ) -> System {
        return System(initialState: initialState, context: context, reducer: reducer, uiBindings: uiBindings, userActions: userActions, feedback: feedback)
    }
    
    func run(callback: @escaping ()->()){
        
        self.callback = callback
        self.userActions.forEach { action in
            action.addListener(system: self)
        }
    }
    
    func run() {
        self.userActions.forEach { action in
            action.addListener(system: self)
        }
    }
    
    var actionExecuting = false
    
    func onUserAction(_ eventAsyncResult: AsyncResult<AppContext,Event>) {
        assert(Thread.isMainThread)
        if(actionExecuting){
            self.eventQueue.append(eventAsyncResult)
        } else {
            actionExecuting = true
            doLoop(eventAsyncResult)
                //IMPURE PART: EXECUTE SIDE EFFECTS
                .runT(self.context, { stateResult in
                    assert(Thread.isMainThread, "ArchitectureKit: Final callback must be run on main thread")
                    if let callback = self.callback {
                        callback()
                        self.actionExecuting = false
                        if let nextEventAsyncResult = self.eventQueue.first {
                            self.eventQueue.removeFirst()
                            self.onUserAction(nextEventAsyncResult)
                        }
                    }
                })
        }
    }
    
    private func doLoop(_ eventResult: AsyncResult<AppContext, Event>) -> AsyncResult<AppContext, Void> {
        return eventResult
            .mapTT { event in
                State.reduce(state: self.initialState, event: event)
            }
            .flatMapTT { state in
                self.getStateAfterFeedback(from: state)
            }
            .flatMapTT { state in
                self.bindUI(state)
            }
    }
    
    private func getStateAfterFeedback(from state: State) -> AsyncResult<AppContext, State> {
        let arrayOfAsyncFeedbacks = self.feedback.map { feedback in
            return AsyncResult<AppContext, Feedback>.pureTT(feedback)
        }
        
        let emptyFeedback = Feedback(condition: { _ in true }, action: { _ in AsyncResult<AppContext, Event>.pureTT(Event.doNothing)})
        let computedAsyncFeedbackResult = arrayOfAsyncFeedbacks.reduce(
            AsyncResult<AppContext, (Feedback, State)>.pureTT((emptyFeedback, state)),
            { (previousFeedbackAndState, feedbackObj) -> (AsyncResult<AppContext, (Feedback,State)>) in
                
                previousFeedbackAndState.flatMapTT { (_, state) -> AsyncResult<AppContext, (Feedback,State)> in
                    feedbackObj.flatMapTT { feedback -> AsyncResult<AppContext, (Feedback,State)> in
                        if(feedback.condition(state)){
                            return feedback.action(state).flatMapTT { newEvent -> AsyncResult<AppContext, (Feedback,State)> in
                                let newState = State.reduce(state: state, event: newEvent)
                                return AsyncResult<AppContext, (Feedback,State)>.pureTT((feedback, newState))
                            }
                        } else {
                            return AsyncResult<AppContext, (Feedback,State)>.pureTT((feedback, state))
                        }
                    }
                }
        })
        return computedAsyncFeedbackResult.mapTT { (feedback,state) in
            return state
        }
    }
    
    private func bindUI(_ state: State) -> AsyncResult<AppContext, Void> {
        return self.uiBindings.reduce(
            AsyncResult<AppContext, Void>.pureTT(()),
            { (previousAsyncResult, currentUiBinding) -> AsyncResult<AppContext, Void> in
                previousAsyncResult.flatMapTT { void in
                    return currentUiBinding(state)
                }
            }
        )
    }
}
