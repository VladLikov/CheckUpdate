// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import UIKit

struct LookUpResponse: Decodable {
    let results: [LookUpResult]
    
    struct LookUpResult: Decodable {
        let version: String
        let minimumOsVersion: String
        let trackViewUrl: URL
    }
}

struct LatestAppStoreVersion {
    let version: String
    let minimumOsVersion: String
    let upgradeURL: URL
}

final class CheckUpdate {
    private let session: URLSession
    private let jsonDecoder: JSONDecoder

    private var currentVersion: String? {
        getBundle(key: "CFBundleShortVersionString")
    }
    
    private var appName: String? {
        getBundle(key: "CFBundleDisplayName")
    }
    
    init(session: URLSession = .shared, jsonDecoder: JSONDecoder = .init()) {
        self.session = session
        self.jsonDecoder = jsonDecoder
    }
    
    public func showUpdate(for appID: String, withConfirmation: Bool, fromVC: UIViewController) async throws {
        
        guard let latestVersion = try await getLatestAvailableVersion(for: appID) else {
            return
        }
            
        guard let currentVersion else {
            return
        }
        
        if currentVersion < latestVersion.version {
            await MainActor.run {
                showAppUpdateAlert(latestVersion: latestVersion, force: !withConfirmation, fromVC: fromVC)
            }
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
    
    private func showAppUpdateAlert(latestVersion: LatestAppStoreVersion,
                                    force: Bool,
                                    fromVC: UIViewController) {
        
        guard let appName = self.appName else { return }

        let title = NSLocalizedString("New version", bundle: .module, comment: "")
        let message = NSLocalizedString("A new version of", bundle: .module, comment: "") + " \(appName) " + NSLocalizedString("is available on AppStore. Update now!", bundle: .module, comment: "")

        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)

        if !force {
            let notNowButton = UIAlertAction(title: NSLocalizedString("Not now", bundle: .module, comment: ""),
                                             style: .default)
            ac.addAction(notNowButton)
        }

        let updateButton = UIAlertAction(title: NSLocalizedString("Update", bundle: .module, comment: ""),
                                         style: .default) { _ in
            UIApplication.shared.open(latestVersion.upgradeURL, options: [:])
        }

        ac.addAction(updateButton)
        
        fromVC.present(ac, animated: true)
        
    }
    
    private func getBundle(key: String) -> String? {
        guard let filePath = Bundle.main.path(forResource: "Info", ofType: "plist") else {
          fatalError("Couldn't find file 'Info.plist'.")
        }
        // Add the file to a dictionary
        let plist = NSDictionary(contentsOfFile: filePath)
        // Check if the variable on plist exists
        guard let value = plist?.object(forKey: key) as? String else {
          fatalError("Couldn't find key '\(key)' in 'Info.plist'.")
        }
        
        return value
    }
}
