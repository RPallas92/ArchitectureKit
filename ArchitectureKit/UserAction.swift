//
//  UserAction.swift
//  FunctionalSwiftArchitectureTests
//
//  Created by Pallas, Ricardo on 12/14/17.
//  Copyright © 2017 Pallas, Ricardo. All rights reserved.
//

import Foundation
import FunctionalKit


class UserAction<State,Event,ErrorType> where ErrorType: Error {
    var listeners = [System<State, Event, ErrorType>]()
    var event: Event
    
    init(from event: Event) {
        self.event = event
    }
    
    func execute() {
        let action = self.event
        notify(action)
    }

    func addListener(listener: System<State, Event, ErrorType>) {
        listeners.append(listener)
    }
    
    func notify(_ action: Event) {
        listeners.forEach { system in
            system.onUserAction(action)
        }
    }
}
