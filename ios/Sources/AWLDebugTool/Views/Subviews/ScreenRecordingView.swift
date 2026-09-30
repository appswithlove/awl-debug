//
//  ScreenRecordingView.swift
//
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

struct ScreenRecordingView: View {
    @ObservedObject var model: ScreenRecorderModel
    /// The export the tester started, so only its row shows the spinner.
    @State private var runningExport: Export?

    private enum Export {
        case last
        case current
    }

    var body: some View {
        Form {
            Section {
                Toggle(
                    LS.Actions.screenRecorderToole,
                    isOn: Binding(
                        get: { model.isOn },
                        set: { model.isScreenRecordingOn = $0 }
                    )
                )

                Picker(LS.Actions.screenRecorderMaxVideoDuration, selection: $model.maxVideoDuration) {
                    ForEach(Constants.MaxScreenVideoDuration.allCases) { videoDuration in
                        Text(videoDuration.ls)
                            .tag(videoDuration)
                    }
                }
                .pickerStyle(.menu)
            } footer: {
                Text(LS.Actions.screenRecorderWarning)
            }

            Section {
                Group {
                    if let date = model.lastRecordingDate {
                        Text(String(format: LS.Actions.screenRecorderLastAvailable,
                                    date.formatted(date: .abbreviated, time: .standard)))
                    } else {
                        Text(LS.Actions.screenRecorderEmpty)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                ProprietaryActionButton(
                    text: LS.Actions.screenRecorderExportLast,
                    icon: .export,
                    iconColor: IconColor.action,
                    isDisabled: model.isExportingVideo,
                    isInProgress: model.isExportingVideo && runningExport == .last
                ) {
                    runningExport = .last
                    model.exportLastVideo()
                }

                ProprietaryActionButton(
                    text: LS.Actions.screenRecorderExportCurrent,
                    icon: .export,
                    iconColor: IconColor.action,
                    isDisabled: model.isExportingVideo,
                    isInProgress: model.isExportingVideo && runningExport == .current
                ) {
                    runningExport = .current
                    model.exportCurrentVideo()
                }
            }
        }
        .panelPage(LS.Headers.screenRecording)
        .alert(LS.Actions.screenRecorderEmpty, isPresented: $model.isRecordingEmpty) {
            Button(LS.Headers.btnDone, role: .cancel) {}
        }
    }
}

#Preview {
    NavigationStack {
        ScreenRecordingView(model: ScreenRecorderModel())
    }
}
