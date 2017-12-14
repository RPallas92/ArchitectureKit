//
//  State.swift
//  FunctionalSwiftArchitectureTests
//
//  Created by Pallas, Ricardo on 12/14/17.
//  Copyright © 2017 Pallas, Ricardo. All rights reserved.
//

import Foundation

struct State {
    var categories: [String]
    var shouldLoadData = false
    
    static var empty = State(categories: [], shouldLoadData: false)
    static func reduce(state: State, event: Event) -> State {
        switch event {
        case .loadCategories:
            var newState = state
            newState.shouldLoadData = true
            newState.categories = []
            return newState
        case .categoriesLoaded(let categoriesResult):
            var newState = state
            newState.shouldLoadData = false
            newState.categories = categoriesResult.tryRight!
            return newState
        case .doNothing:
            return state
        }
    }
}
