//
//  UIButton+ArchitectureExtensions.swift
//  FunctionalSwiftArchitectureTests
//
//  Created by Pallas, Ricardo on 12/14/17.
//  Copyright © 2017 Pallas, Ricardo. All rights reserved.
//

import Foundation
import UIKit

protocol PropertyStoring {
    associatedtype T
    func getAssociatedObject(_ key: UnsafeRawPointer!, defaultValue: T) -> T
}

extension PropertyStoring {
    func getAssociatedObject(_ key: UnsafeRawPointer!, defaultValue: T) -> T {
        guard let value = objc_getAssociatedObject(self, key) as? T else {
            return defaultValue
        }
        return value
    }
}


extension UIButton: PropertyStoring {

    typealias T = UserAction<Any, Any, NSError>

    private struct CustomProperties {
        static var userAction = UserAction<Any, Any, NSError>()
    }
    
    var userAction: UserAction<Any, Any, NSError> {
        get {
            return getAssociatedObject(&CustomProperties.userAction, defaultValue: CustomProperties.userAction)
        }
    }

    func onTap<State,Event,ErrorType>(trigger event: Event.Type) -> UserAction<State,Event,ErrorType> where ErrorType: Error {
        addTarget(self, action: #selector(UIButton.onButtonTapped), for: .touchUpInside)
        userAction.event = event
        return userAction as! UserAction<State, Event, ErrorType>
    }
    
    @objc private func onButtonTapped() {
        self.userAction.execute()
    }
}
