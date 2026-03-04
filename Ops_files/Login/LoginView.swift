import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            TextField("Username", text: $username)
                .textContentType(.username)
                .autocapitalization(.none)
            SecureField("Password", text: $password)
                .textContentType(.password)
            if let msg = errorMessage {
                Text(msg).foregroundStyle(.red).font(.caption)
            }
            Button("Sign In") {
                Task { await signIn() }
            }
            .disabled(username.isEmpty || password.isEmpty)
        }
        .navigationTitle("RSBBQ Operations")
    }

    private func signIn() async {
        errorMessage = nil
        do {
            try await auth.login(username: username, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
