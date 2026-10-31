import SwiftUI

struct ProfileSwitcherView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var creatingProfile = false
    @State private var managingProfiles = false
    @State private var pendingProfile: Profile?
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 108, maximum: 150), spacing: 18)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(auth.profiles) { profile in
                            Button {
                                choose(profile)
                            } label: {
                                VStack(spacing: 8) {
                                    ProfileAvatar(profile: profile, size: 96)
                                        .overlay(alignment: .bottomTrailing) {
                                            if auth.selectedProfile?.id == profile.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(.white, .novaRed)
                                                    .padding(4)
                                            }
                                        }

                                    Text(profile.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                }
                                .padding(10)
                                .novaGlass(cornerRadius: 18)
                            }
                            .buttonStyle(.plain)
                        }

                        if auth.profiles.count < 5 {
                            Button {
                                creatingProfile = true
                            } label: {
                                VStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(
                                            .white.opacity(0.35),
                                            style: StrokeStyle(lineWidth: 2, dash: [6])
                                        )
                                        .frame(width: 96, height: 96)
                                        .overlay {
                                            Image(systemName: "plus")
                                                .font(.title)
                                                .foregroundStyle(.white.opacity(0.8))
                                        }

                                    Text("Add")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                .padding(10)
                                .novaGlass(cornerRadius: 18)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    Button("Manage Profiles") {
                        managingProfiles = true
                    }
                    .font(.footnote.weight(.semibold))
                }
                .padding(.vertical, 18)
            }
            .background(Color.novaBackground.ignoresSafeArea())
            .navigationTitle("Switch Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $creatingProfile) {
                ProfileEditorView(profile: nil)
            }
            .sheet(isPresented: $managingProfiles) {
                ManageProfilesView()
            }
            .sheet(item: $pendingProfile) { profile in
                ProfilePinPrompt(profile: profile) {
                    pendingProfile = nil
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }

    private func choose(_ profile: Profile) {
        if profile.hasPin {
            pendingProfile = profile
        } else {
            auth.select(profile)
            dismiss()
        }
    }
}
