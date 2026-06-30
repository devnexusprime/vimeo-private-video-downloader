import Foundation

@MainActor
final class DownloadProcessService {
    private var process: Process?

    func start(
        request: DownloadRequest,
        onOutput: @escaping @MainActor @Sendable (String) -> Void,
        onCompletion: @escaping @MainActor @Sendable (Result<Void, Error>) -> Void
    ) throws {
        guard process == nil else {
            throw DownloadProcessError.alreadyRunning
        }

        let scriptURL = try ProjectPaths.downloaderScriptURL()
        let interpreter = ProjectPaths.pythonInterpreter()
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = interpreter.executableURL
        process.currentDirectoryURL = scriptURL.deletingLastPathComponent()
        process.arguments = interpreter.leadingArguments + [
            scriptURL.path,
            request.playlistURL,
            request.outputURL.path,
            "--workers",
            String(request.workerCount)
        ]
        process.standardOutput = standardOutput
        process.standardError = standardError

        let emit: @Sendable (Data) -> Void = { data in
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8),
                  !text.isEmpty else {
                return
            }

            Task { @MainActor in
                onOutput(text)
            }
        }

        standardOutput.fileHandleForReading.readabilityHandler = { handle in
            emit(handle.availableData)
        }
        standardError.fileHandleForReading.readabilityHandler = { handle in
            emit(handle.availableData)
        }

        process.terminationHandler = { [weak self] process in
            standardOutput.fileHandleForReading.readabilityHandler = nil
            standardError.fileHandleForReading.readabilityHandler = nil
            let terminationStatus = process.terminationStatus

            Task { @MainActor in
                self?.process = nil
                if terminationStatus == 0 {
                    onCompletion(.success(()))
                } else {
                    onCompletion(.failure(DownloadProcessError.nonZeroExit(terminationStatus)))
                }
            }
        }

        try process.run()
        self.process = process
    }

    func cancel() {
        process?.terminate()
    }
}

enum DownloadProcessError: LocalizedError {
    case alreadyRunning
    case scriptNotFound(URL)
    case nonZeroExit(Int32)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            "A download is already running."
        case .scriptNotFound(let url):
            "The downloader script was not found at \(url.path)."
        case .nonZeroExit(let code):
            "The downloader exited with status \(code)."
        }
    }
}
