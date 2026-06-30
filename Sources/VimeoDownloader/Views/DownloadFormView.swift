import SwiftUI

struct DownloadFormView: View {
    @ObservedObject var store: DownloadStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("Source") {
                    TextField("Vimeo JSON playlist URL", text: $store.playlistURL, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }

                Section("Output") {
                    HStack {
                        TextField("Output filename", text: $store.outputFilename)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            store.chooseOutputFolder()
                        } label: {
                            Label("Choose Folder", systemImage: "folder")
                        }
                    }

                    LabeledContent("Folder") {
                        Text(store.outputFolderURL.path)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Section("Download") {
                    Stepper(value: $store.workerCount, in: 1...64) {
                        LabeledContent("Workers") {
                            Text("\(store.workerCount)")
                                .monospacedDigit()
                        }
                    }

                    HStack {
                        Button {
                            store.startDownload()
                        } label: {
                            Label("Start", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!store.canStartDownload)

                        Button {
                            store.cancelDownload()
                        } label: {
                            Label("Cancel", systemImage: "stop.fill")
                        }
                        .disabled(!store.isRunning)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            .padding(.top)

            Divider()

            ActivityLogView(
                title: "Current Run",
                subtitle: store.activeRecord?.outputURL.lastPathComponent ?? "Ready",
                lines: store.liveLogLines,
                progress: store.liveProgress,
                isRunning: store.isRunning
            )
            .frame(minHeight: 220)
        }
    }
}
