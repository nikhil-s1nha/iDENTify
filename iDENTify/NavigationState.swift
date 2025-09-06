//
//  NavigationState.swift
//  iDENTify
//
//  Created by Nikhil Sinha on 11/21/23.
//

import Foundation

/// Enumeration defining different navigation states for the app
enum NavigationState: CaseIterable {
    case main
    case imagePreview
    case analysis
    case results
    
    /// Returns a user-friendly description of the navigation state
    var description: String {
        switch self {
        case .main:
            return "Main Screen"
        case .imagePreview:
            return "Image Preview"
        case .analysis:
            return "Analysis"
        case .results:
            return "Results"
        }
    }
    
    /// Checks if the navigation state allows going back
    var canGoBack: Bool {
        switch self {
        case .main:
            return false
        case .imagePreview, .analysis, .results:
            return true
        }
    }
    
    /// Returns the previous navigation state
    var previousState: NavigationState? {
        switch self {
        case .main:
            return nil
        case .imagePreview:
            return .main
        case .analysis:
            return .imagePreview
        case .results:
            return .analysis
        }
    }
    
    /// Returns the next navigation state
    var nextState: NavigationState? {
        switch self {
        case .main:
            return .imagePreview
        case .imagePreview:
            return .analysis
        case .analysis:
            return .results
        case .results:
            return nil
        }
    }
    
    /// Validates if a transition to the target state is allowed
    func canTransition(to targetState: NavigationState) -> Bool {
        switch (self, targetState) {
        case (.main, .imagePreview):
            return true
        case (.imagePreview, .main), (.imagePreview, .analysis):
            return true
        case (.analysis, .imagePreview), (.analysis, .results):
            return true
        case (.results, .main), (.results, .imagePreview):
            return true
        default:
            return false
        }
    }
}
