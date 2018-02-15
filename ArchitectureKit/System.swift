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
    
    public static func react(_ action: @escaping (State) -> AsyncResult<Context, Event, ErrorType>, when condition: @escaping (State) -> (Bool)) -> Feedback {
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

public class System<State,Event,ErrorType,Context> where ErrorType: Error {
    
    //TODO don't call UI if State is the same
    //TODO feedback that triggers other feedback
    

    typealias SystemAction = Action<State, Event, ErrorType, Context>
    typealias SystemFeedback = Feedback<State, Event, ErrorType, Context>
    typealias VoidAsyncResult = AsyncResult<Context, Void, ErrorType>
    typealias StateAsyncResult = AsyncResult<Context, State, ErrorType>
    typealias EventAsyncResult = AsyncResult<Context, Event, ErrorType>
    typealias FeedbackAsyncResult = AsyncResult<Context, SystemFeedback, ErrorType>
    typealias FeedbackStateAsyncResult = AsyncResult<Context,(SystemFeedback,State),ErrorType>

    
    var eventQueue = [Event]()
    var callback: (() -> ())? = nil
    
    var initialState: State
    var context: Context
    var reducer: (State, Event) -> State
    var uiBindings: [(State) -> ()]
    var actions: [SystemAction]
    var feedback: [SystemFeedback]
    var currentState: State
    
    private init(
        initialState: State,
        context: Context,
        reducer: @escaping (State, Event) -> State,
        uiBindings: [(State) -> ()],
        actions: [SystemAction],
        feedback: [SystemFeedback]
        ) {
        
        self.initialState = initialState
        self.context = context
        self.reducer = reducer
        self.uiBindings = uiBindings
        self.actions = actions
        self.feedback = feedback
        self.currentState = initialState
        
        self.actions.forEach { action in
            action.addListener(listener: self)
        }
    }
    
    public static func pure(
        initialState: State,
        context: Context,
        reducer: @escaping (State, Event) -> State,
        uiBindings: [(State) -> ()],
        actions: [Action<State, Event, ErrorType, Context>],
        feedback: [Feedback<State, Event, ErrorType, Context>]
        ) -> System {
        return System<State,Event,ErrorType, Context>(initialState: initialState, context: context, reducer: reducer, uiBindings: uiBindings, actions: actions, feedback: feedback)
    }
    
    public func addLoopCallback(callback: @escaping ()->()){
        self.callback = callback
    }
    
    var actionExecuting = false
    
    func onAction(_ action: Event) {
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
                        self.onAction(nextEvent)
                    }
                }
            })
        }
    }
    
    private func doLoop(_ event: Event) -> VoidAsyncResult {
        let maxFeedbackLoops = 5

        return AsyncResult<Context, Event, ErrorType>.pureTT(event)
            .mapTT { event in
                self.reducer(self.currentState, event)
            }
            .flatMapTT { state in
                self.getStateAfterAllFeedback(from: state, maxFeedbackLoops: maxFeedbackLoops)
            }
            .mapTT { state in
                self.currentState = state
                return state
            }
            .flatMapTT { state in
                self.bindUI(state)
        }
    }
    
    private func getStateAfterAllFeedback(from state: State, maxFeedbackLoops: Int) -> StateAsyncResult {
        if (self.feedback.count > 0 && maxFeedbackLoops > 0) {
        
            let computedStateFeedback = runFeedback(from: state)
            return computedStateFeedback.flatMapTT { arg  -> StateAsyncResult in
                
                let (_ ,newState) = arg
                
                let anyFeedbackElse = self.feedback.reduce(false, { (otherLoopRequired, feedback) -> Bool in
                    otherLoopRequired || feedback.condition(newState)
                })
                
                if(anyFeedbackElse){
                    return self.getStateAfterAllFeedback(from: newState, maxFeedbackLoops: maxFeedbackLoops - 1)
                } else {
                    return StateAsyncResult.pureTT(newState)
                }
            }
        } else {
            return StateAsyncResult.pureTT(state)
        }
    }
    
    private func runFeedback(from state:State) -> FeedbackStateAsyncResult {
        let firstFeedback = self.feedback.first!
        let initialValue = FeedbackStateAsyncResult.pureTT((firstFeedback, state))

        return self.feedback.reduce(
            initialValue,
            { (previousFeedbackAndState, feedback) -> FeedbackStateAsyncResult in
                previousFeedbackAndState.flatMapTT { (_, state) -> FeedbackStateAsyncResult in
                    feedback.getStateAfterFeedback(from: state, with: self.reducer)
                        .mapTT { newState in
                            (feedback, newState)
                    }
                }
        })
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
