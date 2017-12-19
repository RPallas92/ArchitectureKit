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

public struct Feedback<State, Event, ErrorType> where ErrorType: Error{
    var condition: (State) -> (Bool)
    var action: (State) -> AsyncResult<AppContext, Event, ErrorType>
    
    static func react(_ action: @escaping (State) -> AsyncResult<AppContext, Event, ErrorType>, when condition: @escaping (State) -> (Bool)) -> Feedback {
        return Feedback(condition: condition, action: action)
    }
}

class System<State,Event,ErrorType> where ErrorType: Error {
    
    var eventQueue = [Event]()
    var callback: (() -> ())? = nil
    
    var initialState: State
    var context: AppContext
    var reducer: (State, Event) -> State
    var uiBindings: [(State) -> ()]
    var userActions: [UserAction<State,Event,ErrorType>]
    var feedback: [Feedback<State, Event, ErrorType>]
    var currentState: State
    
    private init(
        initialState: State,
        context: AppContext,
        reducer: @escaping (State, Event) -> State,
        uiBindings: [(State) -> ()],
        userActions: [UserAction<State,Event,ErrorType>],
        feedback: [Feedback<State, Event, ErrorType>]
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
        userActions: [UserAction<State,Event,ErrorType>],
        feedback: [Feedback<State, Event, ErrorType>]
        ) -> System {
        return System<State,Event,ErrorType>(initialState: initialState, context: context, reducer: reducer, uiBindings: uiBindings, userActions: userActions, feedback: feedback)
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
    
    private func doLoop(_ event: Event) -> AsyncResult<AppContext, Void, ErrorType> {
        return AsyncResult<AppContext, Event, ErrorType>.pureTT(event)
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
    
    private func getStateAfterFeedback(from state: State) -> AsyncResult<AppContext, State, ErrorType> {
        let arrayOfAsyncFeedbacks = self.feedback.map { feedback in
            return AsyncResult<AppContext, Feedback, ErrorType>.pureTT(feedback)
        }
        
        if let firstFeedback = self.feedback.first {
            if(self.feedback.count == 1) {
                if(firstFeedback.condition(state)){
                    return firstFeedback.action(state).flatMapTT { newEvent -> AsyncResult<AppContext,State, ErrorType> in
                        let newState = self.reducer(state,newEvent)
                        return AsyncResult<AppContext, State, ErrorType>.pureTT(newState)
                    }
                } else {
                    return AsyncResult<AppContext, State, ErrorType>.pureTT(state)
                }
                
            } else {
                let tail = arrayOfAsyncFeedbacks[1..<arrayOfAsyncFeedbacks.count]
                
                let initialValue = AsyncResult<AppContext, (Feedback, State), ErrorType>.pureTT((firstFeedback, state))
                
                let computedAsyncFeedbackResult = tail.reduce(
                    initialValue,
                    { (previousFeedbackAndState, feedbackObj) -> (AsyncResult<AppContext, (Feedback<State,Event, ErrorType>,State), ErrorType>) in
                        previousFeedbackAndState.flatMapTT { (_, state) -> AsyncResult<AppContext, (Feedback<State,Event, ErrorType>,State), ErrorType> in
                            feedbackObj.flatMapTT { feedback -> AsyncResult<AppContext, (Feedback<State,Event,ErrorType>,State), ErrorType> in
                                if(feedback.condition(state)){
                                    return feedback.action(state).flatMapTT { newEvent -> AsyncResult<AppContext, (Feedback<State,Event,ErrorType>,State), ErrorType> in
                                        let newState = self.reducer(state,newEvent)
                                        return AsyncResult<AppContext, (Feedback<State,Event,ErrorType>,State),ErrorType>.pureTT((feedback, newState))
                                    }
                                } else {
                                    return AsyncResult<AppContext, (Feedback<State,Event,ErrorType>,State),ErrorType>.pureTT((feedback, state))
                                }
                            }
                        }
                })
                return computedAsyncFeedbackResult.mapTT { (feedback,state) in
                    return state
                }
            }

            
        } else {
            return AsyncResult<AppContext, State, ErrorType>.pureTT(state)
        }
    }
    
    private func bindUI(_ state: State) -> AsyncResult<AppContext, Void, ErrorType> {
        return AsyncResult<AppContext,Void,ErrorType>.unfoldTT { context, continuation in
            self.uiBindings.forEach { uiBinding in
                uiBinding(state)
            }
            continuation(Result.success(()))
        }
    }
}

