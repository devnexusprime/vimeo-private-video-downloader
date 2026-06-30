import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: DownloadStore
    @Binding var selection: SidebarSelection

    var body: some View {
        List(selection: $selection) {
            Section("Download") {
                Label("New Download", systemImage: "arrow.down.circle")
                    .tag(SidebarSelection.newDownload)

                Label("Activity Log", systemImage: "terminal")
                    .tag(SidebarSelection.activity)
            }

            if !store.recentDownloads.isEmpty {
                Section("Recent") {
                    ForEach(store.recentDownloads) { record in
                        RecentDownloadRow(record: record)
                            .tag(SidebarSelection.recent(record.id))
                            .contextMenu {
                                Button("Reveal in Finder") {
                                    store.reveal(record)
                                }
                                .disabled(record.status == .running)
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Vimeo")
    }
}

private struct RecentDownloadRow: View {
    let record: DownloadRecord

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.outputURL.lastPathComponent)
                    .lineLimit(1)

                Text(record.status.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: record.status.symbolName)
                .foregroundStyle(statusStyle)
        }
    }

    private var statusStyle: Color {
        switch record.status {
        case .completed:
            .green
        case .failed:
            .red
        case .cancelled:
            .secondary
        case .running:
            .accentColor
        case .ready:
            .secondary
        }
    }
}
