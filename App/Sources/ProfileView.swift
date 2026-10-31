import SwiftUI

struct ProfileView: View {
    @Environment(AuthStore.self) private var auth

    @State private var showNameEditor = false
    @State private var draftName = ""
    @State private var showSignOut = false
    @State private var showDeleteAccount = false
    @State private var deleteError: String?
    @State private var showSwitcher = false
    @State private var showManager = false
    @State private var serverURL = ServerConfig.baseURL.absoluteString
    @State private var serverStatus: String?

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            List {
                if let account = auth.account {
                    Section {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.novaRed, Color(red: 0.45, green: 0.0, blue: 0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text(account.initials)
                                    .font(.title2.weight(.black))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 58, height: 58)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(account.name)
                                    .font(.headline)
                                Text(account.handle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button("Edit") {
                                draftName = account.name
                                showNameEditor = true
                            }
                            .font(.footnote.weight(.semibold))
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Account")
                    } footer: {
                        Text("Your account is stored securely in the cloud. Sign in with the same email or phone on another device and your profiles, My List, and Continue Watching appear automatically.")
                    }
                }

                if let profile = auth.selectedProfile {
                    Section {
                        Button {
                            showSwitcher = true
                        } label: {
                            HStack(spacing: 14) {
                                ProfileAvatar(profile: profile, size: 52)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(profile.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(profile.isKids ? "Kids profile" : "Standard profile")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text("Switch")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .novaGlass(cornerRadius: 18)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)

                        Button {
                            showManager = true
                        } label: {
                            Label("Manage Profiles", systemImage: "person.2")
                        }
                    } header: {
                        Text("Profiles")
                    } footer: {
                        Text("Each profile keeps its own My List, Continue Watching, and playback position. Add up to five profiles per account.")
                    }
                }

                Section("Widgets") {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Home Screen")
                            Text("Long-press the Home Screen, tap +, search Nova, then add Continue Watching or Trending.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "square.grid.2x2")
                    }

                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Lock Screen")
                            Text("Long-press the Lock Screen, tap Customize, select the widget row, and choose Nova.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.iphone")
                    }
                }

                Section("Server") {
                    TextField("https://nova-api.you.workers.dev", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.footnote.monospaced())

                    Button("Save server URL") {
                        if ServerConfig.set(serverURL) {
                            serverURL = ServerConfig.baseURL.absoluteString
                            serverStatus = "Saved."
                            SharedStore.reloadWidgets()
                        } else {
                            serverStatus = "Invalid URL. Use http:// or https://."
                        }
                    }

                    if let serverStatus {
                        Text(serverStatus)
                            .font(.caption)
                            .foregroundStyle(serverStatus == "Saved." ? Color.green : Color.orange)
                    }

                    Text(ServerConfig.baseURL.absoluteString)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Section("About") {
                    LabeledContent("Version", value: version)
                    LabeledContent("Playback", value: "Internet Archive")

                    Link(destination: URL(string: "https://archive.org")!) {
                        Label("Browse the source archive", systemImage: "building.columns")
                    }

                    Text("Nova is a native SwiftUI client for public-domain and Creative Commons films. It does not host media, sell subscriptions, or collect payment. Not affiliated with Netflix.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        showSignOut = true
                    }
                }

                Section {
                    Button("Delete Account", role: .destructive) {
                        showDeleteAccount = true
                    }

                    if let deleteError {
                        Text(deleteError)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } footer: {
                    Text("Deleting your account permanently removes your profiles, My List, and Continue Watching from the hosted cloud. This cannot be undone.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.novaBackground.ignoresSafeArea())
            .navigationTitle("Profile")
            .alert("Display name", isPresented: $showNameEditor) {
                TextField("Name", text: $draftName)
                Button("Save") {
                    Task { await auth.updateName(draftName) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This name appears on your account and in widgets.")
            }
            .confirmationDialog(
                "Sign out of Nova?",
                isPresented: $showSignOut,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task { await auth.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your profiles, watchlist, and progress stay safely in the cloud.")
            }
            .confirmationDialog(
                "Delete your Nova account?",
                isPresented: $showDeleteAccount,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        do {
                            try await auth.deleteAccount()
                            deleteError = nil
                        } catch {
                            deleteError = error.localizedDescription
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes every profile, My List entry, and playback position. It cannot be undone.")
            }
            .sheet(isPresented: $showSwitcher) {
                ProfileSwitcherView()
            }
            .sheet(isPresented: $showManager) {
                ManageProfilesView()
            }
        }
    }
}
