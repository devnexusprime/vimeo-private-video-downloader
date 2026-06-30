import Foundation

enum UserPreferenceKeys {
    static let defaultWorkerCount = "defaultWorkerCount"
    static let defaultOutputFolderPath = "defaultOutputFolderPath"
    static let openOutputFolderAfterCompletion = "openOutputFolderAfterCompletion"
}

extension UserDefaults {
    func integerWithDefault(forKey key: String, defaultValue: Int) -> Int {
        let value = integer(forKey: key)
        return value == 0 ? defaultValue : value
    }

    func urlWithFallback(forKey key: String, fallback: URL) -> URL {
        guard let path = string(forKey: key),
              !path.isEmpty else {
            return fallback
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
