import Combine
import SwiftUI

/// "Send feedback" on the panel's home page, shown only while AWLDebugFeedback has a configured `feedbackTool`.
struct FeedbackEntryView: View {
    @StateObject private var model = FeedbackEntryModel()

    var body: some View {
        if model.isAvailable {
            Section {
                Button(action: model.start) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LS.Feedback.entry)
                        if model.pendingCount > 0 {
                            Text(LS.Feedback.pending(model.pendingCount))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

@MainActor
final class FeedbackEntryModel: ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var pendingCount = 0

    private let bridge: @MainActor () -> FeedbackBridge?
    private var observer: AnyCancellable?

    init(bridge: @escaping @MainActor () -> FeedbackBridge? = { FeedbackBridge.current }) {
        self.bridge = bridge
        observer = NotificationCenter.default.publisher(for: FeedbackBridge.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
        refresh()
    }

    func refresh() {
        let bridge = bridge()
        isAvailable = bridge != nil
        pendingCount = bridge?.pendingCount ?? 0
    }

    /// Feedback closes the panel before it takes the screenshot.
    func start() {
        bridge()?.start()
    }
}
