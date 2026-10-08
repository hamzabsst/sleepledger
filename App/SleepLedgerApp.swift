import SwiftUI

@main struct SleepLedgerApp: App {
    @State private var store: LedgerStore?
    @State private var startupError: String?
    var body: some Scene {
        WindowGroup {
            Group {
                if let store { RootView().environmentObject(store).preferredColorScheme(store.settings.appearance == "dark" ? .dark : store.settings.appearance == "light" ? .light : nil) }
                else if let startupError {
                    ContentUnavailableView {
                        Label("Storage could not open", systemImage: "externaldrive.badge.exclamationmark")
                    } description: { Text(startupError + " Your data was not reset. Restart the app or recover from a backup.") } actions: { Button("Retry") { load() } }
                } else { ProgressView("Opening your sleep journal…") }
            }
            .task { if store == nil { load() } }
            .onOpenURL { url in
                if store == nil { load() }
                if url.isFileURL { store?.loadFile(url) } else { store?.handle(url) }
            }
        }
    }
    @MainActor private func load() { do { store = try LedgerStore(); startupError = nil } catch { startupError = error.localizedDescription } }
}
