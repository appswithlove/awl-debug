//
//  FirebaseView.swift
//  
//

import SwiftUI

/// Test Crashes: crashes the app on purpose, after a confirmation, to check the app's crash reporting.
struct FirebaseView: View {
    @State private var pendingCrash: TestCrash?

    var body: some View {
        Form {
            Section {
                ForEach(TestCrash.allCases) { crash in
                    ProprietaryActionButton(text: crash.title, icon: .crash, iconColor: .deletion) {
                        pendingCrash = crash
                    }
                }
            }
        }
        .panelPage(LS.Headers.testCrashes)
        .alert(LS.TestCrashes.confirmTitle, isPresented: isConfirming, presenting: pendingCrash) { crash in
            Button(LS.Alert.btnCancel, role: .cancel) {}
            Button(LS.TestCrashes.confirm, role: .destructive) {
                // After the alert has closed, on the main thread, so the crash report shows `TestCrash.run()`.
                DispatchQueue.main.async {
                    crash.run()
                }
            }
        }
    }

    private var isConfirming: Binding<Bool> {
        Binding(get: { pendingCrash != nil }, set: { if !$0 { pendingCrash = nil } })
    }
}

enum TestCrash: CaseIterable, Identifiable {
    case runtime
    case indexOutOfBounds

    var id: Self { self }

    var title: String {
        switch self {
        case .runtime: return LS.TestCrashes.runtime
        case .indexOutOfBounds: return LS.TestCrashes.indexOutOfBounds
        }
    }

    func run() {
        switch self {
        case .runtime:
            fatalError(LS.TestCrashes.message)
        case .indexOutOfBounds:
            let empty: [Int] = []
            _ = empty[0]
        }
    }
}

#Preview {
    NavigationStack {
        FirebaseView()
    }
}
