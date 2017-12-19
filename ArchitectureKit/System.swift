//
//  System.swift
//  FunctionalSwiftArchitectureTests
//
//  Created by Pallas, Ricardo on 12/14/17.
//  Copyright © 2017 Pallas, Ricardo. All rights reserved.
//

import Foundation
import FunctionalKit

protocol AppContext {
    
}

public struct Feedback<State, Event> {
    var condition: (State) -> (Bool)
    var action: (State) -> AsyncResult<AppContext, Event>
    
    static func react(_ action: @escaping (State) -> AsyncResult<AppContext, Event>, when condition: @escaping (State) -> (Bool)) -> Feedback {
        return Feedback(condition: condition, action: action)
    }
}

class System<State,Event> {
    
    var eventQueue = [AsyncResult<AppContext,Event>]()
    var callback: (() -> ())? = nil
    
    var initialState: State
    var context: AppContext
    var reducer: (State, Event) -> State
    var uiBindings: [(State) -> ()]
    var userActions: [UserAction<State, Event>]
    var feedback: [Feedback<State, Event>]
    var currentState: State
    
    private init(
        initialState: State,
        context: AppContext,
        reducer: @escaping (State, Event) -> State,
        uiBindings: [(State) -> ()],
        userActions: [UserAction<State, Event>],
        feedback: [Feedback<State, Event>]
        ) {
        
        self.initialState = initialState
        self.context = context
        self.reducer = reducer
        self.uiBindings = uiBindings
        self.userActions = userActions
        self.feedback = feedback
        self.currentState = initialState
    }
    
    static func pure(
        initialState: State,
        context: AppContext,
        reducer: @escaping (State, Event) -> State,
        uiBindings: [(State) -> ()],
        userActions: [UserAction<State, Event>],
        feedback: [Feedback<State, Event>]
        ) -> System {
        return System<State,Event>(initialState: initialState, context: context, reducer: reducer, uiBindings: uiBindings, userActions: userActions, feedback: feedback)
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
                self.reducer(self.currentState, event)
            }
            .flatMapTT { state in
                self.getStateAfterFeedback(from: state)
            }
            .mapTT { state in
                self.currentState = state
                return state
            }
            .flatMapTT { state in
                self.bindUI(state)
        }
    }
    
    private func getStateAfterFeedback(from state: State) -> AsyncResult<AppContext, State> {
        let arrayOfAsyncFeedbacks = self.feedback.map { feedback in
            return AsyncResult<AppContext, Feedback>.pureTT(feedback)
        }
        
        if let firstFeedback = self.feedback.first {
            if(self.feedback.count == 1) {
                if(firstFeedback.condition(state)){
                    return firstFeedback.action(state).flatMapTT { newEvent -> AsyncResult<AppContext,State> in
                        let newState = self.reducer(state,newEvent)
                        return AsyncResult<AppContext, State>.pureTT(newState)
                    }
                } else {
                    return AsyncResult<AppContext, State>.pureTT(state)
                }
                
            } else {
                let tail = arrayOfAsyncFeedbacks[1..<arrayOfAsyncFeedbacks.count]
                
                let initialValue = AsyncResult<AppContext, (Feedback, State)>.pureTT((firstFeedback, state))
                
                let computedAsyncFeedbackResult = tail.reduce(
                    initialValue,
                    { (previousFeedbackAndState, feedbackObj) -> (AsyncResult<AppContext, (Feedback<State,Event>,State)>) in
                        previousFeedbackAndState.flatMapTT { (_, state) -> AsyncResult<AppContext, (Feedback<State,Event>,State)> in
                            feedbackObj.flatMapTT { feedback -> AsyncResult<AppContext, (Feedback<State,Event>,State)> in
                                if(feedback.condition(state)){
                                    return feedback.action(state).flatMapTT { newEvent -> AsyncResult<AppContext, (Feedback<State,Event>,State)> in
                                        let newState = self.reducer(state,newEvent)
                                        return AsyncResult<AppContext, (Feedback<State,Event>,State)>.pureTT((feedback, newState))
                                    }
                                } else {
                                    return AsyncResult<AppContext, (Feedback<State,Event>,State)>.pureTT((feedback, state))
                                }
                            }
                        }
                })
                return computedAsyncFeedbackResult.mapTT { (feedback,state) in
                    return state
                }
            }

            
        } else {
            return AsyncResult<AppContext, State>.pureTT(state)
        }
    }
    
    private func bindUI(_ state: State) -> AsyncResult<AppContext, Void> {
        return AsyncResult<AppContext, Void>.unfoldTT { context, continuation in
            self.uiBindings.forEach { uiBinding in
                uiBinding(state)
            }
            continuation(Result.success(()))
        }
    }
}

