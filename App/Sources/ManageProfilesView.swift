import SwiftUI

struct ManageProfilesView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var editingProfile: Profile?
    @State private var creatingProfile = false
    @State private var deletingProfile: Profile?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(auth.profiles) { profile in
                        Button {
                            editingProfile = profile
                        } label: {
                            HStack(spacing: 14) {
                                ProfileAvatar(profile: profile, size: 52)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(profile.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    HStack(spacing: 6) {
                                        Text(profile.isKids ? "Kids" : "Standard")
                                        if profile.hasPin {
                                            Text("•")
                                            Label("PIN", systemImage: "lock.fill")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "pencil")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                deletingProfile = profile
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } footer: {
                    Text("Each profile has its own My List and Continue Watching. PINs add a light privacy lock for shared devices.")
                }

                if auth.profiles.count < 5 {
                    Section {
                        Button {
                            creatingProfile = true
                        } label: {
                            Label("Add Profile", systemImage: "plus")
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.novaBackground.ignoresSafeArea())
            .navigationTitle("Manage Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingProfile) { profile in
                ProfileEditorView(profile: profile)
            }
            .sheet(isPresented: $creatingProfile) {
                ProfileEditorView(profile: nil)
            }
            .confirmationDialog(
                "Delete this profile?",
                isPresented: Binding(
                    get: { deletingProfile != nil },
                    set: { if !$0 { deletingProfile = nil } }
                ),
                titleVisibility: .visible,
                presenting: deletingProfile
            ) { profile in
                Button("Delete \(profile.name)", role: .destructive) {
                    Task { await delete(profile) }
                }
                Button("Cancel", role: .cancel) {
                    deletingProfile = nil
                }
            } message: { profile in
                Text("Continue Watching and My List for \(profile.name) will be permanently deleted.")
            }
        }
    }

    @MainActor
    private func delete(_ profile: Profile) async {
        do {
            try await auth.deleteProfile(profile)
            deletingProfile = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            deletingProfile = nil
        }
    }
}
