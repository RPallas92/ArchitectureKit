//
//  UserAction.swift
//  FunctionalSwiftArchitectureTests
//
//  Created by Pallas, Ricardo on 12/14/17.
//  Copyright © 2017 Pallas, Ricardo. All rights reserved.
//

import Foundation

class UserAction<State, Event, ErrorType> where ErrorType: Error {
    var listeners = [System<State, Event,ErrorType>]()
    var event: Event?
    
    init() {}
    
    func execute() {
        if let event = self.event {
            let action = AsyncResult<AppContext, Event, ErrorType>.pureTT(event)
            notify(action)
        }
    }
    
    func addListener(system: System<State, Event, ErrorType>) {
        listeners.append(system)
    }
    
    func notify(_ action: AsyncResult<AppContext, Event, ErrorType>) {
        listeners.forEach { system in
            system.onUserAction(action)
        }
    }
}
