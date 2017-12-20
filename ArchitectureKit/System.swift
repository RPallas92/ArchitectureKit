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
    
    typealias StateAsyncResult = AsyncResult<Context, State, ErrorType>

    var condition: (State) -> (Bool)
    var action: (State) -> AsyncResult<Context, Event, ErrorType>
    
    static func react(_ action: @escaping (State) -> AsyncResult<Context, Event, ErrorType>, when condition: @escaping (State) -> (Bool)) -> Feedback {
        return Feedback(condition: condition, action: action)
    }
    
    func getStateAfterFeedback(from state:State, with reducer:@escaping ((State, Event) -> State)) -> StateAsyncResult {
        if(self.condition(state)){
            return self.action(state).mapTT { newEvent in
                reducer(state,newEvent)
            }
        } else {
            return StateAsyncResult.pureTT(state)
        }
    }
}

class System<State,Event,ErrorType,Context> where ErrorType: Error {
    
    typealias SystemUserAction = UserAction<State,Event,ErrorType,Context>
    typealias SystemFeedback = Feedback<State, Event, ErrorType, Context>
    typealias VoidAsyncResult = AsyncResult<Context, Void, ErrorType>
    typealias StateAsyncResult = AsyncResult<Context, State, ErrorType>
    typealias EventAsyncResult = AsyncResult<Context, Event, ErrorType>
    typealias FeedbackAsyncResult = AsyncResult<Context, SystemFeedback, ErrorType>
    
    var eventQueue = [Event]()
    var callback: (() -> ())? = nil
    
    var initialState: State
    var context: Context
    var reducer: (State, Event) -> State
    var uiBindings: [(State) -> ()]
    var userActions: [SystemUserAction]
    var feedback: [SystemFeedback]
    var currentState: State
    
    private init(
        initialState: State,
        context: Context,
        reducer: @escaping (State, Event) -> State,
        uiBindings: [(State) -> ()],
        userActions: [SystemUserAction],
        feedback: [SystemFeedback]
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
        userActions: [SystemUserAction],
        feedback: [SystemFeedback]
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
            doLoop(action).runT(self.context, { stateResult in
                assert(Thread.isMainThread, "ArchitectureKit: Final callback must be run on main thread")
                if let callback = self.callback {
                    callback()
                    self.actionExecuting = false
                    if let nextEvent = self.eventQueue.first {
                        self.eventQueue.removeFirst()
                        self.onUserAction(nextEvent)
                    }
                }
            })
        }
    }
    
    private func doLoop(_ event: Event) -> VoidAsyncResult {
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
    
    private func getStateAfterFeedback(from state: State) -> StateAsyncResult {
        
        typealias FeedbackStateAsyncResult = AsyncResult<Context,(SystemFeedback,State),ErrorType>
        
        let asyncFeedbacks = self.feedback.map { feedback in
            return FeedbackAsyncResult.pureTT(feedback)
        }
        
        
        if let firstFeedback = self.feedback.first {
            if(self.feedback.count == 1) {
                return firstFeedback.getStateAfterFeedback(from: state, with: self.reducer)
            } else {
                let tail = asyncFeedbacks[1..<asyncFeedbacks.count]
                
                let initialValue = FeedbackStateAsyncResult.pureTT((firstFeedback, state))
                
                let computedAsyncFeedbackResult = tail.reduce(
                    initialValue,
                    { (previousFeedbackAndState, feedbackObj) -> FeedbackStateAsyncResult in
                        previousFeedbackAndState.flatMapTT { (_, state) -> FeedbackStateAsyncResult in
                            feedbackObj.flatMapTT { feedback -> FeedbackStateAsyncResult in
                                feedback.getStateAfterFeedback(from: state, with: self.reducer)
                                    .mapTT { newState in
                                        (feedback, newState)
                                    }
                            }
                        }
                })
                return computedAsyncFeedbackResult.mapTT { (feedback,state) in
                    return state
                }
            }
        } else {
            return StateAsyncResult.pureTT(state)
        }
    }
    
    private func bindUI(_ state: State) -> VoidAsyncResult {
        return VoidAsyncResult.unfoldTT { context, continuation in
            self.uiBindings.forEach { uiBinding in
                uiBinding(state)
            }
            continuation(Result.success(()))
        }
    }
}
