//
//  PendingLinkStore.swift
//  RealRehabPractice
//
//  Holds a pending access code from a deep link so Create Account or Settings can pre-fill it.
//

import SwiftUI
import Combine

final class PendingLinkStore: ObservableObject {
    @Published private(set) var code: String?
    
    func setCode(_ value: String?) {
        code = value
    }
    
    func clearCode() {
        code = nil
    }
}
