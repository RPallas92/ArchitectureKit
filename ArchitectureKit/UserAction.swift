//
//  UserAction.swift
//  FunctionalSwiftArchitectureTests
//
//  Created by Pallas, Ricardo on 12/14/17.
//  Copyright © 2017 Pallas, Ricardo. All rights reserved.
//

import Foundation

class UserAction {
    let asyncResult = AsyncResult<AppContext, Event>.pureTT(Event.loadCategories)
    var listeners = [System]()
    
    init() {
    }
    func execute(value: Int) {
        let action = AsyncResult<AppContext, Int>.pureTT(5).mapTT { number -> Event in
            print("UserAction executed with value: " + String(value))
            return Event.loadCategories
        }
        
        notify(action)
    }
    
    
    func addListener(system: System) {
        listeners.append(system)
    }
    
    func notify(_ action: AsyncResult<AppContext, Event>) {
        listeners.forEach { system in
            system.onUserAction(event: action)
        }
    }
}
