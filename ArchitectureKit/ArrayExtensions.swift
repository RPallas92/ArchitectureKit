//
//  ArrayExtensions.swift
//  ArchitectureKit
//
//  Created by Pallas, Ricardo on 12/20/17.
//  Copyright © 2017 Pallas, Ricardo. All rights reserved.
//

import Foundation


extension Array {
    func getHeadAndTail() -> (Array.Element?, Array) {
        var head: Element?
        var tail:Array = []
        if let first = self.first {
            head = first
            tail = Array(self.dropFirst())
        }
        return (head, tail)
    }
}
