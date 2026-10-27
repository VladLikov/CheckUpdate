import Foundation
import UIKit

public enum CheckUpdateError: Error {
    case noUpdateAvailable
    case cantGetLatestVersion
    case currentVersionIsNil
}

struct LookUpResponse: Decodable {
    let results: [LookUpResult]
    struct LookUpResult: Decodable {
        let version: String
        let minimumOsVersion: String
        let trackViewUrl: URL
    }
}

/// A data-only result. Consumers can decide when and how to present an update.
public struct LatestAppStoreVersion: Sendable {
    public let version: String
    public let minimumOsVersion: String
    public let upgradeURL: URL

    public init(version: String, minimumOsVersion: String, upgradeURL: URL) {
        self.version = version
        self.minimumOsVersion = minimumOsVersion
        self.upgradeURL = upgradeURL
    }
}

public final class CheckUpdate {
    private let session: URLSession
    private let jsonDecoder: JSONDecoder

    private var currentVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private var appName: String? {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
    }

    public init(session: URLSession = .shared, jsonDecoder: JSONDecoder = .init()) {
        self.session = session
        self.jsonDecoder = jsonDecoder
    }

    public func showUpdate(for appID: String, withConfirmation: Bool, fromVC: UIViewController) async throws {
        guard let latestVersion = try await getLatestAvailableVersion(for: appID) else {
            throw CheckUpdateError.cantGetLatestVersion
        }
        try Task.checkCancellation()
        guard let currentVersion else { throw CheckUpdateError.currentVersionIsNil }
        if currentVersion.compareVersion(latestVersion.version) == .orderedAscending {
            let appName = appName
            try await MainActor.run {
                try Task.checkCancellation()
                Self.showAppUpdateAlert(latestVersion: latestVersion, appName: appName,
                                        force: !withConfirmation, fromVC: fromVC)
            }
        } else {
            throw CheckUpdateError.noUpdateAvailable
        }
    }

    public func getLatestAvailableVersion(for appID: String) async throws -> LatestAppStoreVersion? {
        try Task.checkCancellation()
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [URLQueryItem(name: "id", value: appID)]
        guard let url = components?.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.cachePolicy = .useProtocolCachePolicy
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        let decoded = try jsonDecoder.decode(LookUpResponse.self, from: data)
        guard let result = decoded.results.first else { return nil }
        guard ["https", "http"].contains(result.trackViewUrl.scheme?.lowercased() ?? ""),
              result.trackViewUrl.host != nil else { throw URLError(.badURL) }
        return LatestAppStoreVersion(version: result.version,
                                     minimumOsVersion: result.minimumOsVersion,
                                     upgradeURL: result.trackViewUrl)
    }

    @MainActor
    private static func showAppUpdateAlert(latestVersion: LatestAppStoreVersion,
                                           appName: String?, force: Bool, fromVC: UIViewController) {
        let title = String(localized: "New Version", bundle: .module,
                           comment: "Alert title shown when a newer App Store version is available.")
        let prefix = String(localized: "A new version of", bundle: .module,
                            comment: "First part of the update alert message, followed by the app name.")
        let suffix = String(localized: "is available on AppStore. Update now!", bundle: .module,
                            comment: "Second part of the update alert message, shown after the app name.")
        let alert = UIAlertController(title: title, message: "\(prefix) \(appName ?? "") \(suffix)", preferredStyle: .alert)
        if !force {
            alert.addAction(UIAlertAction(title: String(localized: "Not Now", bundle: .module,
                                                        comment: "Cancel button title that dismisses the optional update alert."),
                                          style: .cancel))
        }
        let update = UIAlertAction(title: String(localized: "Update", bundle: .module,
                                                  comment: "Primary button title that opens the App Store update page."),
                                    style: .default) { _ in
            UIApplication.shared.open(latestVersion.upgradeURL, options: [:])
        }
        alert.addAction(update)
        alert.preferredAction = update
        fromVC.present(alert, animated: true)
    }
}

extension String {
    func compareVersion(_ other: String) -> ComparisonResult {
        compare(other, options: .numeric)
    }
}
