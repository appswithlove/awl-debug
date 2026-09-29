//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Foundation

/// Name and email the tester entered, kept on the device so later reports need no prompt.
struct ReporterStore {
    private static let nameKey = "AWLDebugFeedback.reporterName"
    private static let emailKey = "AWLDebugFeedback.reporterEmail"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The saved reporter, or `fallback` (the app's `FeedbackConfig.reporter`) until the tester entered one.
    func load(fallback: FeedbackReporter?) -> FeedbackReporter? {
        guard let name = defaults.string(forKey: Self.nameKey), !name.isBlank else {
            return fallback.flatMap { $0.name.isBlank ? nil : $0 }
        }
        return FeedbackReporter(name: name, email: defaults.string(forKey: Self.emailKey))
    }

    func save(_ reporter: FeedbackReporter) {
        defaults.set(reporter.name.trimmed, forKey: Self.nameKey)
        let email = reporter.email?.trimmed
        defaults.set(email?.isEmpty == false ? email : nil, forKey: Self.emailKey)
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isBlank: Bool {
        trimmed.isEmpty
    }
}
