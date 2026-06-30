import SwiftUI

struct DownloadRecordDetailView: View {
    @ObservedObject var store: DownloadStore
    let record: DownloadRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("Summary") {
                    LabeledContent("Status") {
                        Label(record.status.title, systemImage: record.status.symbolName)
                    }

                    LabeledContent("Output") {
                        Text(record.outputURL.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    LabeledContent("Started") {
                        Text(AppFormatters.date.string(from: record.startedAt))
                    }

                    if let completedAt = record.completedAt {
                        LabeledContent("Finished") {
                            Text(AppFormatters.date.string(from: completedAt))
                        }
                    }

                    LabeledContent("Workers") {
                        Text("\(record.workerCount)")
                    }
                }

                Section {
                    Button {
                        store.reveal(record)
                    } label: {
                        Label("Reveal in Finder", systemImage: "finder")
                    }
                    .disabled(record.status == .running)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            .padding(.top)

            Divider()

            ActivityLogView(
                title: "Run Log",
                subtitle: record.outputURL.lastPathComponent,
                lines: record.logLines,
                progress: record.progress,
                isRunning: record.status == .running
            )
            .frame(minHeight: 260)
        }
    }
}
