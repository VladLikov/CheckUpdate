// The Swift Programming Language
// https://docs.swift.org/swift-book

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

public struct LatestAppStoreVersion: Sendable {
    let version: String
    let minimumOsVersion: String
    let upgradeURL: URL
}

final public class CheckUpdate {
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
            
        guard let currentVersion else {
            throw CheckUpdateError.currentVersionIsNil
        }
        
        if currentVersion.compareVersion(latestVersion.version) == .orderedAscending {
            let appName = appName
            await MainActor.run {
                Self.showAppUpdateAlert(latestVersion: latestVersion,
                                        appName: appName,
                                        force: !withConfirmation,
                                        fromVC: fromVC)
            }
        } else {
            throw CheckUpdateError.noUpdateAvailable
        }
    }
    
    public func getLatestAvailableVersion(for appID: String) async throws -> LatestAppStoreVersion? {
        
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(appID)") else {
            return nil
        }
        
        let request = URLRequest(url: url)
        let (data, _) = try await session.data(for: request)
        let response = try jsonDecoder.decode(LookUpResponse.self, from: data)
                    
        return response.results.first.map {
            .init(version: $0.version,
                  minimumOsVersion: $0.minimumOsVersion,
                  upgradeURL: $0.trackViewUrl)
        }
    }
    
    @MainActor
    private static func showAppUpdateAlert(latestVersion: LatestAppStoreVersion,
                                           appName: String?,
                                           force: Bool,
                                           fromVC: UIViewController) {
        
        let title = String(
            localized: "New Version",
            bundle: .module,
            comment: "Alert title shown when a newer App Store version is available."
        )
        let messagePrefix = String(
            localized: "A new version of",
            bundle: .module,
            comment: "First part of the update alert message, followed by the app name."
        )
        let messageSuffix = String(
            localized: "is available on AppStore. Update now!",
            bundle: .module,
            comment: "Second part of the update alert message, shown after the app name."
        )
        let message = "\(messagePrefix) \(appName ?? "") \(messageSuffix)"

        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)

        if !force {
            let notNowButton = UIAlertAction(title: String(
                                                 localized: "Not Now",
                                                 bundle: .module,
                                                 comment: "Cancel button title that dismisses the optional update alert."
                                             ),
                                             style: .cancel)
            ac.addAction(notNowButton)
        }

        let updateButton = UIAlertAction(title: String(
                                             localized: "Update",
                                             bundle: .module,
                                             comment: "Primary button title that opens the App Store update page."
                                         ),
                                         style: .default) { _ in
            UIApplication.shared.open(latestVersion.upgradeURL, options: [:])
        }

        ac.addAction(updateButton)
        ac.preferredAction = updateButton
        
        fromVC.present(ac, animated: true)
    }
}

extension String {
    func compareVersion(_ other: String) -> ComparisonResult {
        return self.compare(other, options: .numeric)
    }
}
