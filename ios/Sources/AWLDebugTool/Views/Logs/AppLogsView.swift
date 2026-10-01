import SwiftUI
import UIKit

/// Logs module: the app's own log entries, searchable, filterable by level and exportable.
struct AppLogsView: View {
    @ObservedObject var store: AppLogsStore

    @State private var expandedEntries: Set<UUID> = []
    @State private var isPinnedToBottom = true
    @State private var exportFile: ExportFile?
    @State private var copiedEntry: UUID?

    private static let bottomID = "bottom"
    private let pollTimer = Timer.publish(every: AppLogsStore.pollInterval, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            Toggle(LS.AppLogs.record, isOn: $store.isRecording)
                .padding(.horizontal, 16)
                .padding(.top, 4)
            LevelChips(selectedLevels: $store.selectedLevels)
                .padding(.horizontal, 16)
            EntryList
        }
        .overlay {
            if store.filteredEntries.isEmpty {
                Text(LS.AppLogs.empty)
                    .foregroundStyle(.secondary)
            }
        }
        .searchable(text: $store.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: LS.AppLogs.search)
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
        .panelPage(LS.AppLogs.title) {
            ActionsMenu
        }
        .sheet(item: $exportFile) { file in
            ActivityView(items: [file.url])
        }
        .task {
            await store.readOSLog()
        }
        .onReceive(pollTimer) { _ in
            Task { await store.readOSLog() }
        }
    }

    @ViewBuilder private var EntryList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(store.filteredEntries) { entry in
                    EntryRow(entry: entry,
                             isExpanded: expandedEntries.contains(entry.id),
                             isCopied: copiedEntry == entry.id)
                        .contentShape(Rectangle())
                        .onTapGesture { toggle(entry) }
                        .onLongPressGesture { copy(entry) }
                        // VoiceOver: activate expands like a tap, "Copy" like a long press.
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { toggle(entry) }
                        .accessibilityAction(named: LS.Actions.copy) { copy(entry) }
                }
                // Visible only while the list is scrolled to the end; new entries then keep it there.
                Color.clear
                    .frame(height: 1)
                    .id(Self.bottomID)
                    .listRowSeparator(.hidden)
                    .onAppear { isPinnedToBottom = true }
                    .onDisappear { isPinnedToBottom = false }
            }
            .listStyle(.plain)
            .onAppear {
                proxy.scrollTo(Self.bottomID, anchor: .bottom)
            }
            .onChange(of: store.filteredEntries.last?.id) { _ in
                if isPinnedToBottom {
                    proxy.scrollTo(Self.bottomID, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder private var ActionsMenu: some View {
        Menu {
            Button(action: export) {
                Label(LS.AppLogs.export, systemImage: Image.AppIcon.export.rawValue)
            }
            .disabled(store.filteredEntries.isEmpty)
            Picker(LS.AppLogs.limit, selection: $store.limit) {
                ForEach(Constants.Defaults.defaultNumberOfLogs, id: \.self) {
                    Text(verbatim: "\($0)")
                }
            }
            .pickerStyle(.menu)
            Button(role: .destructive, action: store.clear) {
                Label(LS.AppLogs.clear, systemImage: Image.AppIcon.clear.rawValue)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func toggle(_ entry: AppLogEntry) {
        if expandedEntries.contains(entry.id) {
            expandedEntries.remove(entry.id)
        } else {
            expandedEntries.insert(entry.id)
        }
    }

    private func copy(_ entry: AppLogEntry) {
        UIPasteboard.general.string = [entry.message, entry.errorDescription].compactMap { $0 }.joined(separator: "\n")
        copiedEntry = entry.id
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if copiedEntry == entry.id {
                copiedEntry = nil
            }
        }
    }

    private func export() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(AppLogsStore.exportFilename)
        do {
            try store.exportText(appInfo: Self.appInfo).write(to: url, atomically: true, encoding: .utf8)
            exportFile = ExportFile(url: url)
        } catch {
            print("\(LS.logWatermark) \(error)")
        }
    }

    private static var appInfo: String {
        let info = Bundle.main.infoDictionary
        let app = "\(info?["CFBundleName"] as? String ?? "") \(info?["CFBundleShortVersionString"] as? String ?? "") (\(info?["CFBundleVersion"] as? String ?? ""))"
        let device = "\(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)"
        return "\(app)\n\(device)"
    }
}

private struct ExportFile: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct LevelChips: View {
    @Binding var selectedLevels: Set<AWLDebugLogLevel>

    var body: some View {
        FlowLayout {
            ForEach(AWLDebugLogLevel.allCases, id: \.self) { level in
                let isSelected = selectedLevels.contains(level)
                Button {
                    if isSelected {
                        selectedLevels.remove(level)
                    } else {
                        selectedLevels.insert(level)
                    }
                } label: {
                    Text(level.rawValue)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        // The background color of the panel reads on the filled chip in light and dark mode.
                        .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : level.color)
                        .background(isSelected ? level.color : Color.clear, in: Capsule())
                        .overlay(Capsule().stroke(level.color))
                        // 44 pt tall to tap, the capsule stays compact.
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EntryRow: View {
    let entry: AppLogEntry
    let isExpanded: Bool
    let isCopied: Bool

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Time, level and tag in one line; with large text the tag moves below.
            FlowLayout(spacing: 6) {
                Text(Self.timeFormatter.string(from: entry.date))
                    .foregroundStyle(Color.logTimeColor)
                Text(entry.level.rawValue)
                    .bold()
                    .foregroundStyle(entry.level.color)
                if let tag = entry.tag {
                    Text(tag)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if isCopied {
                    Text(LS.AppLogs.copied)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption2)
            Text(entry.message)
                .font(.callout)
                .lineLimit(isExpanded ? nil : 3)
            if isExpanded, let errorDescription = entry.errorDescription {
                Text(errorDescription)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension AWLDebugLogLevel {
    var color: Color {
        switch self {
        case .debug: return .statusNeutral
        case .info: return .statusRedirect
        case .warn: return .statusWarning
        case .error: return .statusError
        }
    }
}
