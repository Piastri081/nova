import SwiftUI

struct ProfileEditorView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let profile: Profile?

    @State private var name: String
    @State private var avatarColor: String
    @State private var isKids: Bool
    @State private var pin: String
    @State private var clearPin: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let palette = [
        "#E50914", "#F5A623", "#2ECC71", "#3498DB",
        "#9B59B6", "#E91E63", "#00BCD4", "#FF7043"
    ]

    init(profile: Profile?) {
        self.profile = profile
        _name = State(initialValue: profile?.name ?? "")
        _avatarColor = State(initialValue: profile?.avatarColor ?? "#E50914")
        _isKids = State(initialValue: profile?.isKids ?? false)
        _pin = State(initialValue: "")
        _clearPin = State(initialValue: false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Profile name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                Section("Avatar color") {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 46), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(palette, id: \.self) { hex in
                            Button {
                                avatarColor = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if avatarColor == hex {
                                            Image(systemName: "checkmark")
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .overlay {
                                        Circle()
                                            .stroke(
                                                .white.opacity(avatarColor == hex ? 0.9 : 0.2),
                                                lineWidth: avatarColor == hex ? 2 : 1
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Toggle("Kids profile", isOn: $isKids)
                } footer: {
                    Text("Kids profiles only receive family, animation, comedy, and adventure titles from the catalog.")
                }

                Section {
                    if profile?.hasPin == true {
                        Toggle("Remove existing PIN", isOn: $clearPin)
                    }

                    if !clearPin {
                        SecureField(
                            profile?.hasPin == true ? "New 4-digit PIN (optional)" : "4-digit PIN (optional)",
                            text: $pin
                        )
                        .keyboardType(.numberPad)
                        .onChange(of: pin) { _, newValue in
                            pin = String(newValue.filter(\.isNumber).prefix(4))
                        }
                    }
                } header: {
                    Text("Profile PIN")
                } footer: {
                    Text("A PIN is a convenience lock for shared devices. It is stored as a salted hash on your server, never in plain text.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(profile == nil ? "New Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .disabled(isSaving)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a profile name."
            return
        }

        if !pin.isEmpty && pin.count != 4 {
            errorMessage = "A PIN must be exactly 4 digits."
            return
        }

        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            do {
                if let profile {
                    _ = try await auth.updateProfile(
                        profile,
                        name: trimmed,
                        avatarColor: avatarColor,
                        isKids: isKids,
                        pin: pin.isEmpty ? nil : pin,
                        clearPin: clearPin
                    )
                } else {
                    _ = try await auth.createProfile(
                        name: trimmed,
                        avatarColor: avatarColor,
                        isKids: isKids,
                        pin: pin.isEmpty ? nil : pin
                    )
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}
