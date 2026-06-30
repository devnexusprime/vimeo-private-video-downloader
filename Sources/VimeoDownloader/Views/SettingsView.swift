import SwiftUI

struct SettingsView: View {
    @AppStorage(UserPreferenceKeys.defaultWorkerCount) private var defaultWorkerCount = 24
    @AppStorage(UserPreferenceKeys.defaultOutputFolderPath) private var defaultOutputFolderPath = ""
    @AppStorage(UserPreferenceKeys.openOutputFolderAfterCompletion) private var openOutputFolderAfterCompletion = false

    var body: some View {
        Form {
            Section("Defaults") {
                Stepper(value: $defaultWorkerCount, in: 1...64) {
                    LabeledContent("Workers") {
                        Text("\(defaultWorkerCount)")
                            .monospacedDigit()
                    }
                }

                HStack {
                    LabeledContent("Output Folder") {
                        Text(outputFolderDisplayPath)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Button {
                        chooseDefaultOutputFolder()
                    } label: {
                        Label("Choose", systemImage: "folder")
                    }
                }

                Toggle("Reveal output folder after completion", isOn: $openOutputFolderAfterCompletion)
            }

            Section {
                Button("Reset Defaults") {
                    defaultWorkerCount = 24
                    defaultOutputFolderPath = ""
                    openOutputFolderAfterCompletion = false
                }
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(width: 520)
    }

    private var outputFolderDisplayPath: String {
        if defaultOutputFolderPath.isEmpty {
            return FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first?.path
                ?? FileManager.default.homeDirectoryForCurrentUser.path
        }
        return defaultOutputFolderPath
    }

    private func chooseDefaultOutputFolder() {
        let currentURL = URL(fileURLWithPath: outputFolderDisplayPath, isDirectory: true)
        if let selectedURL = FolderPicker.chooseFolder(startingAt: currentURL) {
            defaultOutputFolderPath = selectedURL.path
        }
    }
}
