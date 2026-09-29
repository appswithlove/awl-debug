//
//  ScreenRecordingView.swift
//
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

struct ScreenRecordingView: View {
    @ObservedObject var model: ScreenRecorderModel

    var body: some View {
        Section {
            Toggle(
                LS.Actions.screenRecorderToole,
                isOn: Binding(
                    get: { model.isOn },
                    set: { model.isScreenRecordingOn = $0 }
                )
            )

            if let date = model.lastRecordingDate {
                Text(String(format: LS.Actions.screenRecorderLastAvailable,
                            date.formatted(date: .abbreviated, time: .standard)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ProprietaryActionButton(
                text: LS.Actions.screenRecorderExportLast,
                icon: .export,
                iconColor: IconColor.action,
                isDisabled: model.isExportingVideo,
                action: model.exportLastVideo
            )

            ProprietaryActionButton(
                text: LS.Actions.screenRecorderExportCurrent,
                icon: .export,
                iconColor: IconColor.action,
                isDisabled: model.isExportingVideo,
                action: model.exportCurrentVideo
            )

            HStack {
                Text(LS.Actions.screenRecorderMaxVideoDuration)

                Picker(LS.Actions.screenRecorderMaxVideoDuration, selection: $model.maxVideoDuration) {
                    ForEach(Constants.MaxScreenVideoDuration.allCases) { videoDuration in
                        Text(videoDuration.ls)
                            .tag(videoDuration)
                    }
                }
                .pickerStyle(.segmented)
            }
        } header: {
            HStack {
                Text(LS.Headers.screenRecording)
                if model.isOn {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                }
            }
        } footer: {
            Text(LS.Actions.screenRecorderWarning)
        }
        .alert(LS.Actions.screenRecorderEmpty, isPresented: $model.isRecordingEmpty) {
            Button(LS.Headers.btnDone, role: .cancel) {}
        }
    }
}

#Preview {
    Form {
        ScreenRecordingView(model: ScreenRecorderModel())
    }
}
