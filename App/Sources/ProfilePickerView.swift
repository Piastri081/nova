import SwiftUI

struct ProfilePickerView: View {
    @Environment(AuthStore.self) private var auth

    @State private var creatingProfile = false
    @State private var managingProfiles = false
    @State private var pendingProfile: Profile?
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 170), spacing: 20)]

    var body: some View {
        ZStack {
            Color.novaBackground.ignoresSafeArea()

            LinearGradient(
                colors: [Color.novaRed.opacity(0.22), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()
            .blur(radius: 70)

            ScrollView {
                VStack(spacing: 26) {
                    NovaLogo(size: 34)

                    VStack(spacing: 6) {
                        Text("Who's watching?")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        if let account = auth.account {
                            Text("Signed in as \(account.handle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(auth.profiles) { profile in
                            Button {
                                choose(profile)
                            } label: {
                                VStack(spacing: 10) {
                                    ProfileAvatar(profile: profile, size: 118)

                                    Text(profile.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                }
                                .padding(12)
                                .novaGlass(cornerRadius: 22)
                            }
                            .buttonStyle(.plain)
                        }

                        if auth.profiles.count < 5 {
                            Button {
                                creatingProfile = true
                            } label: {
                                VStack(spacing: 10) {
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .stroke(
                                            .white.opacity(0.35),
                                            style: StrokeStyle(lineWidth: 2, dash: [7])
                                        )
                                        .frame(width: 118, height: 118)
                                        .overlay {
                                            Image(systemName: "plus")
                                                .font(.largeTitle)
                                                .foregroundStyle(.white.opacity(0.8))
                                        }

                                    Text("Add Profile")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                                .padding(12)
                                .novaGlass(cornerRadius: 22)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 24) {
                        Button("Manage Profiles") {
                            managingProfiles = true
                        }

                        Button("Sign Out") {
                            Task { await auth.signOut() }
                        }
                        .foregroundStyle(.secondary)
                    }
                    .font(.footnote.weight(.semibold))
                }
                .padding(24)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
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
            }
        }
    }

    private func choose(_ profile: Profile) {
        if profile.hasPin {
            pendingProfile = profile
        } else {
            auth.select(profile)
        }
    }
}
