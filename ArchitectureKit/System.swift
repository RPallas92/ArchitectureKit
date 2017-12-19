//
//  System.swift
//  FunctionalSwiftArchitectureTests
//
//  Created by Pallas, Ricardo on 12/14/17.
//  Copyright © 2017 Pallas, Ricardo. All rights reserved.
//

import Foundation
import FunctionalKit

public struct Feedback<State, Event, ErrorType, Context> where ErrorType: Error{
    var condition: (State) -> (Bool)
    var action: (State) -> AsyncResult<Context, Event, ErrorType>
    
    static func react(_ action: @escaping (State) -> AsyncResult<Context, Event, ErrorType>, when condition: @escaping (State) -> (Bool)) -> Feedback {
        return Feedback(condition: condition, action: action)
    }
}

class System<State,Event,ErrorType,Context> where ErrorType: Error {
    
    var eventQueue = [Event]()
    var callback: (() -> ())? = nil
    
    var initialState: State
    var context: Context
    var reducer: (State, Event) -> State
    var uiBindings: [(State) -> ()]
    var userActions: [UserAction<State,Event,ErrorType,Context>]
    var feedback: [Feedback<State, Event, ErrorType, Context>]
    var currentState: State
    
    private init(
        initialState: State,
        context: Context,
        reducer: @escaping (State, Event) -> State,
        uiBindings: [(State) -> ()],
        userActions: [UserAction<State,Event,ErrorType,Context>],
        feedback: [Feedback<State, Event, ErrorType, Context>]
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
        context: Context,
        reducer: @escaping (State, Event) -> State,
        uiBindings: [(State) -> ()],
        userActions: [UserAction<State,Event,ErrorType,Context>],
        feedback: [Feedback<State, Event, ErrorType, Context>]
        ) -> System {
        return System<State,Event,ErrorType, Context>(initialState: initialState, context: context, reducer: reducer, uiBindings: uiBindings, userActions: userActions, feedback: feedback)
    }
    
    func run(callback: @escaping ()->()){
        
        self.callback = callback
        self.userActions.forEach { action in
            action.addListener(listener: self)
        }
    }
    
    func run() {
        self.userActions.forEach { action in
            action.addListener(listener: self)
        }
    }
    
    var actionExecuting = false
    
    func onUserAction(_ action: Event) {
        assert(Thread.isMainThread)
        if(actionExecuting){
            self.eventQueue.append(action)
        } else {
            actionExecuting = true
            doLoop(action)
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
    
    private func doLoop(_ event: Event) -> AsyncResult<Context, Void, ErrorType> {
        return AsyncResult<Context, Event, ErrorType>.pureTT(event)
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
    
    private func getStateAfterFeedback(from state: State) -> AsyncResult<Context, State, ErrorType> {
        let arrayOfAsyncFeedbacks = self.feedback.map { feedback in
            return AsyncResult<Context, Feedback, ErrorType>.pureTT(feedback)
        }
        
        if let firstFeedback = self.feedback.first {
            if(self.feedback.count == 1) {
                if(firstFeedback.condition(state)){
                    return firstFeedback.action(state).flatMapTT { newEvent -> AsyncResult<Context,State, ErrorType> in
                        let newState = self.reducer(state,newEvent)
                        return AsyncResult<Context, State, ErrorType>.pureTT(newState)
                    }
                } else {
                    return AsyncResult<Context, State, ErrorType>.pureTT(state)
                }
                
            } else {
                let tail = arrayOfAsyncFeedbacks[1..<arrayOfAsyncFeedbacks.count]
                
                let initialValue = AsyncResult<Context, (Feedback, State), ErrorType>.pureTT((firstFeedback, state))
                
                let computedAsyncFeedbackResult = tail.reduce(
                    initialValue,
                    { (previousFeedbackAndState, feedbackObj) -> (AsyncResult<Context, (Feedback<State,Event, ErrorType,Context>,State), ErrorType>) in
                        previousFeedbackAndState.flatMapTT { (_, state) -> AsyncResult<Context, (Feedback<State,Event, ErrorType,Context>,State), ErrorType> in
                            feedbackObj.flatMapTT { feedback -> AsyncResult<Context, (Feedback<State,Event,ErrorType,Context>,State), ErrorType> in
                                if(feedback.condition(state)){
                                    return feedback.action(state).flatMapTT { newEvent -> AsyncResult<Context,(Feedback<State,Event,ErrorType,Context>,State), ErrorType> in
                                        let newState = self.reducer(state,newEvent)
                                        return AsyncResult<Context, (Feedback<State,Event,ErrorType,Context>,State),ErrorType>.pureTT((feedback, newState))
                                    }
                                } else {
                                    return AsyncResult<Context, (Feedback<State,Event,ErrorType,Context>,State),ErrorType>.pureTT((feedback, state))
                                }
                            }
                        }
                })
                return computedAsyncFeedbackResult.mapTT { (feedback,state) in
                    return state
                }
            }

            
        } else {
            return AsyncResult<Context, State, ErrorType>.pureTT(state)
        }
    }
    
    private func bindUI(_ state: State) -> AsyncResult<Context, Void, ErrorType> {
        return AsyncResult<Context,Void,ErrorType>.unfoldTT { context, continuation in
            self.uiBindings.forEach { uiBinding in
                uiBinding(state)
            }
            continuation(Result.success(()))
        }
    }
}

