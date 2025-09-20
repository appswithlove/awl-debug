//
//  ScreenRecordingView.swift
//  
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

struct ScreenRecordingView: View {
    let isScreenRecordingOn: Binding<Bool?>
    let isScreenRecordingOnByDefault: Binding<Bool>
    let exportLastVideo: () -> Void
    let isExportingVideo: Bool
    let exportCurrentVideo: () -> Void
    let maxVideoDuration: Binding<Constants.MaxScreenVideoDuration>
    
    var body: some View {
        Section {
            Toggle(
                Constants.Actions.screenRecorderToole,
                isOn: Binding(
                    get: {
                        if let userValue = isScreenRecordingOn.wrappedValue {
                            return userValue
                        } else {
                            return isScreenRecordingOnByDefault.wrappedValue
                        }
                    },
                    set: { newValue in
                        isScreenRecordingOn.wrappedValue = newValue
                    }
                )
            )
            
            ProprietaryActionButton(
                text: Constants.Actions.screenRecorderExportLast,
                iconName: Constants.Image.export,
                iconColor: IconColor.action,
                isDisabled: isExportingVideo,
                action: exportLastVideo
            )
            
            ProprietaryActionButton(
                text: Constants.Actions.screenRecorderExportCurrent,
                iconName: Constants.Image.export,
                iconColor: IconColor.action,
                isDisabled: isExportingVideo,
                action: exportCurrentVideo
            )
            
            HStack {
                Text(Constants.Actions.screenRecorderMaxVideoDuration)
                
                Picker(Constants.Actions.screenRecorderMaxVideoDuration, selection: maxVideoDuration) {
                    ForEach(Constants.MaxScreenVideoDuration.allCases) { videoDuration in
                        Text(videoDuration.ls)
                            .tag(videoDuration)
                    }
                }
                .pickerStyle(.segmented)
            }
        } header: {
            Text(Constants.Headers.screenRecording)
        }
    }
}

#Preview {
    ScreenRecordingView(
        isScreenRecordingOn: .constant(true),
        isScreenRecordingOnByDefault: .constant(true),
        exportLastVideo: {},
        isExportingVideo: false,
        exportCurrentVideo: {},
        maxVideoDuration: .constant(.fiveMinutes)
    )
}
