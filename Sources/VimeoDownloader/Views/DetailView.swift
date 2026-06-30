import SwiftUI

struct DetailView: View {
    @ObservedObject var store: DownloadStore
    let selection: SidebarSelection

    var body: some View {
        Group {
            switch selection {
            case .newDownload:
                DownloadFormView(store: store)
            case .activity:
                ActivityLogView(
                    title: "Activity Log",
                    subtitle: store.activeRecord?.outputURL.lastPathComponent ?? "No active download",
                    lines: store.liveLogLines,
                    progress: store.liveProgress,
                    isRunning: store.isRunning
                )
            case .recent(let id):
                if let record = store.record(for: id) {
                    DownloadRecordDetailView(store: store, record: record)
                } else {
                    ContentUnavailableView("Download Not Found", systemImage: "questionmark.folder")
                }
            }
        }
        .navigationTitle(navigationTitle)
    }

    private var navigationTitle: String {
        switch selection {
        case .newDownload:
            "New Download"
        case .activity:
            "Activity"
        case .recent:
            "Download"
        }
    }
}
