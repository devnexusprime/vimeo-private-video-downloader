import Foundation

enum DownloadStatus: String, Codable, CaseIterable {
    case ready
    case running
    case completed
    case failed
    case cancelled

    var title: String {
        switch self {
        case .ready:
            "Ready"
        case .running:
            "Running"
        case .completed:
            "Completed"
        case .failed:
            "Failed"
        case .cancelled:
            "Cancelled"
        }
    }

    var symbolName: String {
        switch self {
        case .ready:
            "clock"
        case .running:
            "arrow.down.circle"
        case .completed:
            "checkmark.circle"
        case .failed:
            "xmark.octagon"
        case .cancelled:
            "stop.circle"
        }
    }
}

struct DownloadRequest: Equatable {
    var playlistURL: String
    var outputFilename: String
    var outputFolderURL: URL
    var workerCount: Int

    var outputURL: URL {
        outputFolderURL.appendingPathComponent(outputFilename)
    }
}

struct DownloadRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var playlistURL: String
    var outputURL: URL
    var workerCount: Int
    var status: DownloadStatus
    var startedAt: Date
    var completedAt: Date?
    var progress: Double?
    var logLines: [String]

    init(request: DownloadRequest) {
        self.id = UUID()
        self.playlistURL = request.playlistURL
        self.outputURL = request.outputURL
        self.workerCount = request.workerCount
        self.status = .running
        self.startedAt = Date()
        self.completedAt = nil
        self.progress = nil
        self.logLines = []
    }
}

enum SidebarSelection: Hashable {
    case newDownload
    case activity
    case recent(UUID)

    init(rawValue: String) {
        if rawValue.hasPrefix("recent:"),
           let uuid = UUID(uuidString: String(rawValue.dropFirst("recent:".count))) {
            self = .recent(uuid)
        } else if rawValue == "activity" {
            self = .activity
        } else {
            self = .newDownload
        }
    }

    var rawValue: String {
        switch self {
        case .newDownload:
            "new"
        case .activity:
            "activity"
        case .recent(let id):
            "recent:\(id.uuidString)"
        }
    }
}
