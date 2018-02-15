//
//  Action.swift
//  FunctionalSwiftArchitectureTests
//
//  Created by Pallas, Ricardo on 12/14/17.
//  Copyright © 2017 Pallas, Ricardo. All rights reserved.
//

import Foundation
import UIKit
import FunctionalKit

public class Action<State,Event,ErrorType, Context> where ErrorType: Error {
    var listeners = [System<State, Event, ErrorType, Context>]()

    func addListener(listener: System<State, Event, ErrorType, Context>) {
        listeners.append(listener)
    }
    
    func notify(_ action: Event) {
        listeners.forEach { system in
            system.onAction(action)
        }
    }
}

public class CustomAction<State,Event,ErrorType, Context>: Action<State, Event, ErrorType, Context> where ErrorType: Error {
    var event: Event
    
    public init(trigger event: Event) {
        self.event = event
    }
    
    public func execute() {
        let action = self.event
        notify(action)
    }
}

public class UIButtonAction<State,Event,ErrorType, Context>: Action<State, Event, ErrorType, Context> where ErrorType: Error {
    
    var events = [UIControlEvents.RawValue: Event]()
    let button: UIButton
    
    
    public init(button: UIButton) {
        self.button = button
    }
    
    public func onTap(trigger: Event) {
        self.button.addTarget(self, action:#selector(self.didTap), for: .touchUpInside)
    }
    
    @objc func didTap() {
        guard let action = self.events[UIControlEvents.touchUpInside.rawValue] else {
            return
        }
        self.notify(action)
    }
}
