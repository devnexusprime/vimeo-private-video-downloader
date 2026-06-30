import AppKit
import Foundation

@MainActor
final class DownloadStore: ObservableObject {
    @Published var playlistURL = ""
    @Published var outputFilename = "video.mp4"
    @Published var outputFolderURL: URL
    @Published var workerCount: Int
    @Published private(set) var isRunning = false
    @Published private(set) var recentDownloads: [DownloadRecord]
    @Published private(set) var liveLogLines: [String] = []
    @Published private(set) var liveProgress: Double?
    @Published private(set) var activeRecordID: UUID?
    @Published var selectedRecordID: UUID?

    private let service: DownloadProcessService
    private let historyStore: DownloadHistoryStore
    private var isCancelling = false

    init(
        service: DownloadProcessService = DownloadProcessService(),
        historyStore: DownloadHistoryStore = DownloadHistoryStore()
    ) {
        self.service = service
        self.historyStore = historyStore
        self.recentDownloads = historyStore.load()
        self.workerCount = UserDefaults.standard.integerWithDefault(
            forKey: UserPreferenceKeys.defaultWorkerCount,
            defaultValue: 24
        )
        self.outputFolderURL = UserDefaults.standard.urlWithFallback(
            forKey: UserPreferenceKeys.defaultOutputFolderPath,
            fallback: FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
        )
    }

    var canStartDownload: Bool {
        !isRunning
            && playlistURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && outputFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var activeRecord: DownloadRecord? {
        guard let activeRecordID else {
            return nil
        }
        return recentDownloads.first { $0.id == activeRecordID }
    }

    func applyPreferences(workerCount defaultWorkerCount: Int, outputFolderPath: String) {
        if !isRunning {
            workerCount = max(1, defaultWorkerCount)
        }

        if !outputFolderPath.isEmpty,
           !isRunning {
            outputFolderURL = URL(fileURLWithPath: outputFolderPath, isDirectory: true)
        }
    }

    func chooseOutputFolder() {
        if let selectedURL = FolderPicker.chooseFolder(startingAt: outputFolderURL) {
            outputFolderURL = selectedURL
        }
    }

    func startDownload() {
        guard canStartDownload else {
            return
        }

        let request = DownloadRequest(
            playlistURL: playlistURL.trimmingCharacters(in: .whitespacesAndNewlines),
            outputFilename: sanitizedOutputFilename(outputFilename),
            outputFolderURL: outputFolderURL,
            workerCount: max(1, workerCount)
        )

        var record = DownloadRecord(request: request)
        record.logLines.append("Starting \(request.outputURL.lastPathComponent)")
        recentDownloads.insert(record, at: 0)
        recentDownloads = Array(recentDownloads.prefix(12))
        activeRecordID = record.id
        selectedRecordID = record.id
        liveLogLines = record.logLines
        liveProgress = nil
        isRunning = true
        isCancelling = false
        historyStore.save(recentDownloads)

        do {
            try service.start(
                request: request,
                onOutput: { [weak self] text in
                    self?.appendProcessOutput(text)
                },
                onCompletion: { [weak self] result in
                    self?.finishDownload(result)
                }
            )
        } catch {
            appendLogLine(error.localizedDescription)
            finishDownload(.failure(error))
        }
    }

    func cancelDownload() {
        guard isRunning else {
            return
        }
        isCancelling = true
        appendLogLine("Cancellation requested.")
        service.cancel()
    }

    func revealOutputFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([outputFolderURL])
    }

    func reveal(_ record: DownloadRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([record.outputURL])
    }

    func record(for id: UUID?) -> DownloadRecord? {
        guard let id else {
            return nil
        }
        return recentDownloads.first { $0.id == id }
    }

    private func appendProcessOutput(_ text: String) {
        let lines = text
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            appendLogLine(line)
            updateProgress(from: line)
        }
    }

    private func appendLogLine(_ line: String) {
        liveLogLines.append(line)
        liveLogLines = Array(liveLogLines.suffix(300))

        guard let activeRecordID,
              let index = recentDownloads.firstIndex(where: { $0.id == activeRecordID }) else {
            return
        }

        recentDownloads[index].logLines.append(line)
        recentDownloads[index].logLines = Array(recentDownloads[index].logLines.suffix(300))
        historyStore.save(recentDownloads)
    }

    private func updateProgress(from line: String) {
        guard let progress = ProgressParser.segmentProgress(from: line) else {
            return
        }

        liveProgress = progress
        updateActiveRecord { record in
            record.progress = progress
        }
    }

    private func finishDownload(_ result: Result<Void, Error>) {
        defer {
            isRunning = false
            isCancelling = false
            activeRecordID = nil
            historyStore.save(recentDownloads)
        }

        if isCancelling {
            appendLogLine("Download cancelled.")
            updateActiveRecord { record in
                record.status = .cancelled
                record.completedAt = Date()
            }
            return
        }

        switch result {
        case .success:
            liveProgress = 1
            appendLogLine("Download completed.")
            updateActiveRecord { record in
                record.status = .completed
                record.progress = 1
                record.completedAt = Date()
            }
            if UserDefaults.standard.bool(forKey: UserPreferenceKeys.openOutputFolderAfterCompletion) {
                revealOutputFolder()
            }
        case .failure(let error):
            appendLogLine(error.localizedDescription)
            updateActiveRecord { record in
                record.status = .failed
                record.completedAt = Date()
            }
        }
    }

    private func updateActiveRecord(_ update: (inout DownloadRecord) -> Void) {
        guard let activeRecordID,
              let index = recentDownloads.firstIndex(where: { $0.id == activeRecordID }) else {
            return
        }
        update(&recentDownloads[index])
        historyStore.save(recentDownloads)
    }

    private func sanitizedOutputFilename(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "video.mp4" : trimmed
    }
}
