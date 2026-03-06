import SwiftUI

/// Add more names here when you add image sets to Assets.xcassets (e.g. "LoginBG3", "LoginBG4").
private let loginBackgroundImageNames = ["LoginBG1", "LoginBG2"]

private let fallbackGradient = LinearGradient(
    colors: [Color.blue, Color.black],
    startPoint: .top, endPoint: .bottom)

/// Sign-in screen: username/password fields and JWT login via ``AuthManager``.
///
/// Shown when the user is not authenticated. On success, the app switches to ``HomeView``.
/// Uses a random background image from the login set and a fallback gradient if none are available.
struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    /// Randomly chosen background image name; set once when the view appears.
    @State private var backgroundImageName: String?

    var body: some View {
        ZStack {
            // Full-screen layer so image extends under status bar and home indicator
            backgroundView
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .ignoresSafeArea(.all)

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 0)

                        VStack(alignment: .leading, spacing: 16) {
                            Text("RSBBQ Operations")
                                .font(.title2.weight(.semibold))
                            TextField("Username", text: $username)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .textFieldStyle(.roundedBorder)
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                .textFieldStyle(.roundedBorder)

                            if let msg = errorMessage {
                                Text(msg)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            Button {
                                Task { await signIn() }
                            } label: {
                                Text("Sign In")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(username.isEmpty || password.isEmpty)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .frame(maxWidth: 320)
                        .frame(maxWidth: .infinity)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onAppear {
            if backgroundImageName == nil {
                backgroundImageName = loginBackgroundImageNames.randomElement()
            }
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if let name = backgroundImageName {
            Image(name)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            fallbackGradient
        }
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
