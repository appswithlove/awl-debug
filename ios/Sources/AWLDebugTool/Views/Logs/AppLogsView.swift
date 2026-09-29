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
            LevelChips(selectedLevels: $store.selectedLevels)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
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
        .navigationTitle(LS.AppLogs.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Toggle(LS.AppLogs.record, isOn: $store.isRecording)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityLabel(LS.AppLogs.record)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                ActionsMenu
            }
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
            Button(LS.AppLogs.export, action: export)
                .disabled(store.filteredEntries.isEmpty)
            Picker(LS.AppLogs.limit, selection: $store.limit) {
                ForEach(Constants.Defaults.defaultNumberOfLogs, id: \.self) {
                    Text("\($0)")
                }
            }
            .pickerStyle(.menu)
            Button(LS.AppLogs.clear, role: .destructive, action: store.clear)
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
        HStack(spacing: 8) {
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
                        .foregroundStyle(isSelected ? Color.white : level.color)
                        .background(isSelected ? level.color : Color.clear, in: Capsule())
                        .overlay(Capsule().stroke(level.color))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer()
        }
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
            HStack(spacing: 6) {
                Text(Self.timeFormatter.string(from: entry.date))
                    .foregroundColor(.logTimeColor)
                Text(entry.level.rawValue)
                    .bold()
                    .foregroundStyle(entry.level.color)
                if let tag = entry.tag {
                    Text(tag)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
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
        case .debug: return .gray
        case .info: return .blue
        case .warn: return .orange
        case .error: return .red
        }
    }
}
