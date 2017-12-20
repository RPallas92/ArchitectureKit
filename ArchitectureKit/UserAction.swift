//
//  UserAction.swift
//  FunctionalSwiftArchitectureTests
//
//  Created by Pallas, Ricardo on 12/14/17.
//  Copyright © 2017 Pallas, Ricardo. All rights reserved.
//

import Foundation
import FunctionalKit

// TODO: UIButtonUserAction(uiButtonInstance).onTap

public class UserAction<State,Event,ErrorType, Context> where ErrorType: Error {
    var listeners = [System<State, Event, ErrorType, Context>]()
    var event: Event
    
    public init(trigger event: Event) {
        self.event = event
    }
    
    public func execute() {
        let action = self.event
        notify(action)
    }

    func addListener(listener: System<State, Event, ErrorType, Context>) {
        listeners.append(listener)
    }
    
    func notify(_ action: Event) {
        listeners.forEach { system in
            system.onUserAction(action)
        }
    }
}
