//
//  FireDeeplinkView.swift
//  AWLDebugTool
//

import SwiftUI

struct FireDeeplinkView: View {
    let deeplink: AWLDeeplink
    let manager: DeeplinksManager

    @Environment(\.dismiss) private var dismiss

    private let delayOptions: [TimeInterval] = [5, 10]
    @State private var selectedDelay: TimeInterval = 5
    @State private var isScheduling = false
    @State private var toast: String? = nil
    @State private var isMissingPermission = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deeplink.title)
                        .font(.headline)
                    Text(deeplink.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                Button {
                    manager.fireNow(deeplink)
                    // dismiss()
                } label: {
                    HStack {
                        Text(LS.Deeplinks.fireNow)
                        Spacer()
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.blue)
                    }
                }
            } header: {
                Text(LS.Deeplinks.whileActive)
            }

            Section {
                Picker(LS.Deeplinks.delay, selection: $selectedDelay) {
                    ForEach(delayOptions, id: \.self) { delay in
                        Text(delayLabel(delay)).tag(delay)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                Button {
                    scheduleNotification()
                } label: {
                    HStack {
                        Text(LS.Deeplinks.schedule)
                        Spacer()
                        if isScheduling {
                            ProgressView()
                        } else {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
                .disabled(isScheduling)
            } header: {
                Text(LS.Deeplinks.coldStart)
            } footer: {
                Text(LS.Deeplinks.coldStartFooter)
            }

            if let toast {
                Section {
                    Text(toast)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                    if isMissingPermission {
                        Button(LS.Actions.openAppSettings) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(deeplink.title)
    }

    private func delayLabel(_ delay: TimeInterval) -> String {
        "\(Int(delay))\(LS.Deeplinks.seconds)"
    }

    private func scheduleNotification() {
        isScheduling = true
        manager.fireWithDelay(deeplink, delay: selectedDelay) { result in
            isScheduling = false
            switch result {
            case .success:
                isMissingPermission = false
                toast = LS.Deeplinks.scheduledSuccess(Int(selectedDelay))
            case .failure(let error):
                isMissingPermission = error == .permissionDenied
                toast = error.localizedDescription
            }
        }
    }
}
