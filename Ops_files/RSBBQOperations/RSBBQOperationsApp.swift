//
//  RSBBQOperationsApp.swift
//  RSBBQOperations
//
//  Created by Michael Chavez on 2/21/26. test
//

import SwiftUI

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
