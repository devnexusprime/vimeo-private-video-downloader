import Foundation

struct DownloadHistoryStore {
    private let defaults: UserDefaults
    private let key = "downloadHistory"
    private let maxRecords = 12
    private let maxPersistedLogLines = 80

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [DownloadRecord] {
        guard let data = defaults.data(forKey: key) else {
            return []
        }

        do {
            return try JSONDecoder().decode([DownloadRecord].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ records: [DownloadRecord]) {
        let trimmed = records.prefix(maxRecords).map { record in
            var copy = record
            copy.logLines = Array(copy.logLines.suffix(maxPersistedLogLines))
            return copy
        }

        do {
            let data = try JSONEncoder().encode(trimmed)
            defaults.set(data, forKey: key)
        } catch {
            defaults.removeObject(forKey: key)
        }
    }
}
