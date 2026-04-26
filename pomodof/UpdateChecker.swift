import Foundation
import Combine

@MainActor
class UpdateChecker: ObservableObject {

    @Published var latestVersion: String?
    @Published var updateURL: URL?
    @Published var checkFailed: Bool = false

    var checkForUpdates: Bool {
        get { UserDefaults.standard.bool(forKey: "checkForUpdates") }
        set {
            UserDefaults.standard.set(newValue, forKey: "checkForUpdates")
            objectWillChange.send()
            if newValue { check() }
        }
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var hasUpdate: Bool {
        guard let latest = latestVersion else { return false }
        return latest.compare(currentVersion, options: .numeric) == .orderedDescending
    }

    func check() {
        guard checkForUpdates else { return }
        checkFailed = false

        Task {
            let url = URL(string: "https://api.github.com/repos/metecapar/pomodof/releases/latest")!
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    checkFailed = true
                    return
                }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let htmlURL = json["html_url"] as? String else {
                    checkFailed = true
                    return
                }
                let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                latestVersion = version
                updateURL = URL(string: htmlURL)
            } catch {
                checkFailed = true
            }
        }
    }
}
