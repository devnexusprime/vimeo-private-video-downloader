import Foundation

struct PythonInterpreter {
    var executableURL: URL
    var leadingArguments: [String]
}

enum ProjectPaths {
    static func repositoryRoot() -> URL {
        if let value = ProcessInfo.processInfo.environment["VIMEO_DOWNLOADER_ROOT"],
           !value.isEmpty {
            return URL(fileURLWithPath: value, isDirectory: true)
        }

        let bundleURL = Bundle.main.bundleURL
        if bundleURL.pathExtension == "app" {
            return bundleURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    }

    static func downloaderScriptURL() throws -> URL {
        let url = repositoryRoot().appendingPathComponent("vimeo-private-video-dl.py")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DownloadProcessError.scriptNotFound(url)
        }
        return url
    }

    static func pythonInterpreter() -> PythonInterpreter {
        let venvPythonURL = repositoryRoot().appendingPathComponent(".venv/bin/python")
        if FileManager.default.isExecutableFile(atPath: venvPythonURL.path) {
            return PythonInterpreter(executableURL: venvPythonURL, leadingArguments: [])
        }

        return PythonInterpreter(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            leadingArguments: ["python3"]
        )
    }
}
