import SwiftUI

struct ProfilePinPrompt: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let profile: Profile
    var onUnlocked: () -> Void = {}

    @State private var pin = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                ProfileAvatar(profile: profile, size: 96)
                    .padding(.top, 18)

                VStack(spacing: 6) {
                    Text(profile.name)
                        .font(.title2.weight(.bold))
                    Text("Enter the 4-digit PIN for this profile.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                SecureField("••••", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .padding(.vertical, 14)
                    .background(Color.novaSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    }
                    .onChange(of: pin) { _, newValue in
                        pin = String(newValue.filter(\.isNumber).prefix(4))
                    }
                    .padding(.horizontal, 24)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button {
                    unlock()
                } label: {
                    if isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text("Unlock")
                    }
                }
                .buttonStyle(NovaPrimaryButtonStyle())
                .disabled(pin.count != 4 || isWorking)
                .opacity(pin.count == 4 ? 1 : 0.45)
                .padding(.horizontal, 24)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.novaBackground.ignoresSafeArea())
            .navigationTitle("Profile Lock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(.ultraThinMaterial)
    }

    private func unlock() {
        guard pin.count == 4, !isWorking else { return }
        isWorking = true
        errorMessage = nil

        Task { @MainActor in
            do {
                try await auth.unlock(profile, pin: pin)
                dismiss()
                onUnlocked()
            } catch {
                errorMessage = error.localizedDescription
                pin = ""
                isWorking = false
            }
        }
    }
}
