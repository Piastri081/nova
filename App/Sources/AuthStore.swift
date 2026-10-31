import Foundation
import Observation

struct CodeChallenge: Equatable {
    let identifier: String
    let channel: String
    let devCode: String?
    let resendAvailableAt: Date
}

enum AuthStage {
    case loading
    case signedOut
    case codeSent(CodeChallenge)
    case choosingProfile
    case signedIn
}

@Observable
@MainActor
final class AuthStore {
    var stage: AuthStage = .loading
    var account: AuthUser?
    var profiles: [Profile] = []
    var selectedProfile: Profile?
    var isWorking = false
    var errorMessage: String?

    private let api = APIClient.shared

    init() {
        Task { await bootstrap() }
    }

    func bootstrap() async {
        guard Keychain.token != nil else {
            stage = .signedOut
            return
        }

        do {
            let session = try await api.session()
            account = session.account
            profiles = session.profiles
            restoreProfile()
        } catch {
            Keychain.setToken(nil)
            account = nil
            profiles = []
            selectedProfile = nil
            ProfileContext.set(nil)
            stage = .signedOut
        }
    }

    func requestCode(_ identifier: String) async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let response = try await api.requestCode(identifier: identifier)
            stage = .codeSent(
                CodeChallenge(
                    identifier: identifier,
                    channel: response.channel,
                    devCode: response.devCode,
                    resendAvailableAt: Date().addingTimeInterval(30)
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verify(identifier: String, code: String) async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let response = try await api.verify(identifier: identifier, code: code)
            Keychain.setToken(response.token)
            account = response.account
            profiles = response.profiles
            restoreProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func backToIdentifier() {
        errorMessage = nil
        stage = .signedOut
    }

    func select(_ profile: Profile) {
        selectedProfile = profile
        ProfileContext.set(profile.id)
        errorMessage = nil
        stage = .signedIn
    }

    func updateName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            account = try await api.updateName(trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshProfiles() async {
        do {
            profiles = try await api.profiles()
            if let selectedProfile,
               let updated = profiles.first(where: { $0.id == selectedProfile.id }) {
                self.selectedProfile = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func createProfile(
        name: String,
        avatarColor: String,
        isKids: Bool,
        pin: String?
    ) async throws -> Profile {
        let profile = try await api.createProfile(
            name: name,
            avatarColor: avatarColor,
            isKids: isKids,
            pin: pin
        )
        profiles.append(profile)
        return profile
    }

    @discardableResult
    func updateProfile(
        _ profile: Profile,
        name: String,
        avatarColor: String,
        isKids: Bool,
        pin: String?,
        clearPin: Bool
    ) async throws -> Profile {
        let updated = try await api.updateProfile(
            id: profile.id,
            name: name,
            avatarColor: avatarColor,
            isKids: isKids,
            pin: pin,
            clearPin: clearPin
        )

        if let index = profiles.firstIndex(where: { $0.id == updated.id }) {
            profiles[index] = updated
        }
        if selectedProfile?.id == updated.id {
            selectedProfile = updated
        }

        return updated
    }

    func deleteProfile(_ profile: Profile) async throws {
        _ = try await api.deleteProfile(id: profile.id)
        profiles.removeAll { $0.id == profile.id }

        if selectedProfile?.id == profile.id {
            selectedProfile = nil
            ProfileContext.set(nil)
            if let next = profiles.first {
                select(next)
            } else {
                stage = .choosingProfile
            }
        }
    }

    func unlock(_ profile: Profile, pin: String) async throws {
        _ = try await api.unlockProfile(id: profile.id, pin: pin)
        select(profile)
    }

    func signOut() async {
        _ = try? await api.logout()
        Keychain.setToken(nil)
        account = nil
        profiles = []
        selectedProfile = nil
        ProfileContext.set(nil)
        SharedStore.clear()
        errorMessage = nil
        stage = .signedOut
    }

    func deleteAccount() async throws {
        _ = try await api.deleteAccount()
        Keychain.setToken(nil)
        account = nil
        profiles = []
        selectedProfile = nil
        ProfileContext.set(nil)
        SharedStore.clear()
        errorMessage = nil
        stage = .signedOut
    }

    private func restoreProfile() {
        if let id = ProfileContext.currentID,
           let saved = profiles.first(where: { $0.id == id }) {
            select(saved)
            return
        }

        if profiles.count == 1, let only = profiles.first {
            select(only)
            return
        }

        selectedProfile = nil
        ProfileContext.set(nil)
        stage = .choosingProfile
    }
}
