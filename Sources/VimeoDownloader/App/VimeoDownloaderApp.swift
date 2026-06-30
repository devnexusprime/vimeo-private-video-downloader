import AppKit
import SwiftUI

@main
struct VimeoDownloaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DownloadStore()

    var body: some Scene {
        WindowGroup("Vimeo Downloader") {
            ContentView(store: store)
                .frame(minWidth: 920, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
        .commands {
            DownloadCommands(store: store)
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct DownloadCommands: Commands {
    @ObservedObject var store: DownloadStore

    var body: some Commands {
        CommandMenu("Download") {
            Button("Start Download") {
                store.startDownload()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!store.canStartDownload)

            Button("Cancel Download") {
                store.cancelDownload()
            }
            .keyboardShortcut(".", modifiers: [.command])
            .disabled(!store.isRunning)

            Divider()

            Button("Reveal Output Folder") {
                store.revealOutputFolder()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}
