//
//  RSBBQOperationsApp.swift
//  RSBBQOperations
//
//  Created by Michael Chavez on 2/21/26. test
//

import SwiftUI

/// The main entry point for the RSBBQ Operations iOS app.
///
/// Presents either the store dashboard (``HomeView``) when authenticated, or ``LoginView`` when not.
/// Authentication state is managed by ``AuthManager`` and provided to the environment.
@main
struct RSBBQOperationsApp: App {
    @StateObject private var auth = AuthManager()
    var body: some Scene {
        WindowGroup {
            if auth.isAuthenticated {
                HomeView()
                    .environmentObject(auth)
            } else {
                LoginView()
                    .environmentObject(auth)
            }
        }
    }
}
