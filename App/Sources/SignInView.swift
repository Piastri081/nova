import SwiftUI

private enum AuthMethod: String, CaseIterable {
    case email
    case phone

    var label: String {
        switch self {
        case .email: return "Email"
        case .phone: return "Phone"
        }
    }

    var placeholder: String {
        switch self {
        case .email: return "you@example.com"
        case .phone: return "+1 555 123 4567"
        }
    }
}

private enum AuthField {
    case identifier
    case code
}

struct SignInView: View {
    @Environment(AuthStore.self) private var auth

    @State private var method: AuthMethod = .email
    @State private var identifier = ""
    @State private var code = ""
    @State private var showServer = false
    @State private var serverURL = ServerConfig.baseURL.absoluteString
    @State private var serverStatus: String?
    @FocusState private var focusedField: AuthField?

    private var challenge: CodeChallenge? {
        if case .codeSent(let challenge) = auth.stage {
            return challenge
        }
        return nil
    }

    private var normalizedIdentifier: String {
        identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        switch method {
        case .email:
            let value = normalizedIdentifier
            return value.contains("@") && value.contains(".") && !value.contains(" ")
        case .phone:
            return normalizedIdentifier.filter(\.isNumber).count >= 7
        }
    }

    var body: some View {
        ZStack {
            Color.novaBackground.ignoresSafeArea()

            LinearGradient(
                colors: [Color.novaRed.opacity(0.28), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()
            .blur(radius: 60)

            ScrollView {
                VStack(spacing: 26) {
                    Spacer(minLength: 34)

                    NovaLogo(size: 42)

                    VStack(spacing: 8) {
                        Text("Unlimited films. Zero paywall.")
                            .font(.title3.weight(.bold))
                            .multilineTextAlignment(.center)

                        Text("Public-domain cinema, beautifully presented.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let challenge {
                        codeEntry(challenge)
                    } else {
                        identifierEntry
                    }

                    if let message = auth.errorMessage {
                        errorBanner(message)
                    }

                    serverSection

                    Spacer(minLength: 24)

                    Text("By continuing you confirm you are 13 or older and will only stream titles you are legally allowed to watch. Nova does not host media and is not affiliated with Netflix.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Identifier

    private var identifierEntry: some View {
        VStack(spacing: 16) {
            Picker("Sign in with", selection: $method) {
                ForEach(AuthMethod.allCases, id: \.self) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: method) { _, _ in
                identifier = ""
                auth.errorMessage = nil
            }

            TextField(method.placeholder, text: $identifier)
                .keyboardType(method == .email ? .emailAddress : .phonePad)
                .textContentType(method == .email ? .emailAddress : .telephoneNumber)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .identifier)
                .submitLabel(.continue)
                .onSubmit(continueTapped)
                .padding(14)
                .background(Color.novaSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }

            Button(action: continueTapped) {
                if auth.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(NovaPrimaryButtonStyle())
            .disabled(!canContinue || auth.isWorking)
            .opacity(canContinue ? 1 : 0.45)

            Text("We'll send a 6-digit code. No password. No payment.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .novaGlass(cornerRadius: 24)
    }

    private func continueTapped() {
        guard canContinue, !auth.isWorking else { return }
        focusedField = nil
        Task { await auth.requestCode(normalizedIdentifier) }
    }

    // MARK: - Code

    private func codeEntry(_ challenge: CodeChallenge) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Check your \(challenge.channel == "sms" ? "messages" : "email")")
                    .font(.headline)

                Text(challenge.identifier)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            TextField("000000", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focusedField, equals: .code)
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .tracking(10)
                .padding(.vertical, 14)
                .background(Color.novaSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                }
                .onChange(of: code) { _, newValue in
                    let digits = newValue.filter(\.isNumber)
                    code = String(digits.prefix(6))
                }
                .onAppear {
                    focusedField = .code
                }

            if let devCode = challenge.devCode {
                Text("Development code: \(devCode)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            }

            Button {
                focusedField = nil
                Task { await auth.verify(identifier: challenge.identifier, code: code) }
            } label: {
                if auth.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text("Verify & Sign In")
                }
            }
            .buttonStyle(NovaPrimaryButtonStyle())
            .disabled(code.count != 6 || auth.isWorking)
            .opacity(code.count == 6 ? 1 : 0.45)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, Int(challenge.resendAvailableAt.timeIntervalSince(context.date).rounded(.up)))

                Button(remaining > 0 ? "Resend in \(remaining)s" : "Resend code") {
                    guard remaining == 0, !auth.isWorking else { return }
                    Task { await auth.requestCode(challenge.identifier) }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(remaining > 0 ? Color.secondary : Color.white)
                .disabled(remaining > 0 || auth.isWorking)
            }

            Button("Use a different \(challenge.channel == "sms" ? "phone number" : "email")") {
                code = ""
                auth.backToIdentifier()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .novaGlass(cornerRadius: 24)
    }

    // MARK: - Server

    private var serverSection: some View {
        DisclosureGroup(isExpanded: $showServer) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("https://nova-api.your-name.workers.dev", text: $serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color.novaSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button("Save server URL") {
                    if ServerConfig.set(serverURL) {
                        serverURL = ServerConfig.baseURL.absoluteString
                        serverStatus = "Saved. New requests will use this server."
                    } else {
                        serverStatus = "That doesn't look like a valid http(s) URL."
                    }
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(.novaRed)

                if let serverStatus {
                    Text(serverStatus)
                        .font(.caption)
                        .foregroundStyle(serverStatus.hasPrefix("Saved") ? .green : .orange)
                }

                Text("Current: \(ServerConfig.baseURL.absoluteString)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if ServerConfig.isPlaceholder {
                    Text("This build still points at the placeholder server. Deploy Backend/ and paste your Worker URL here, or set the API_BASE_URL build variable.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Server", systemImage: "server.rack")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
        .foregroundStyle(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
