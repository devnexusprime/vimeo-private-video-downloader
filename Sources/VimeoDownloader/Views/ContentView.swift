import SwiftUI

struct ContentView: View {
    @ObservedObject var store: DownloadStore
    @SceneStorage("sidebar.selection") private var selectionRawValue = SidebarSelection.newDownload.rawValue
    @AppStorage(UserPreferenceKeys.defaultWorkerCount) private var defaultWorkerCount = 24
    @AppStorage(UserPreferenceKeys.defaultOutputFolderPath) private var defaultOutputFolderPath = ""

    private var selection: Binding<SidebarSelection> {
        Binding {
            SidebarSelection(rawValue: selectionRawValue)
        } set: { newValue in
            selectionRawValue = newValue.rawValue
            if case .recent(let id) = newValue {
                store.selectedRecordID = id
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, selection: selection)
        } detail: {
            DetailView(store: store, selection: selection.wrappedValue)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.startDownload()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .disabled(!store.canStartDownload)

                Button {
                    store.cancelDownload()
                } label: {
                    Label("Cancel", systemImage: "stop.fill")
                }
                .disabled(!store.isRunning)
            }
        }
        .onAppear {
            store.applyPreferences(
                workerCount: defaultWorkerCount,
                outputFolderPath: defaultOutputFolderPath
            )
        }
        .onChange(of: defaultWorkerCount) { _, newValue in
            store.applyPreferences(workerCount: newValue, outputFolderPath: defaultOutputFolderPath)
        }
        .onChange(of: defaultOutputFolderPath) { _, newValue in
            store.applyPreferences(workerCount: defaultWorkerCount, outputFolderPath: newValue)
        }
    }
}
