//
//  AboutView.swift
//  
//
//  Created by Hrvoje Hajduković on 20.09.2025..
//

import SwiftUI

struct AboutView: View {
    let internetAccesStatusIcon: String
    let internetAccesStatusColor: Color
    
    var body: some View {
        Section {
            DeviceInfoView
            ApplicationInfoView
            ClockInfoView
            InternetAccessInfoView
        } header: {
            Text(Constants.Headers.aboutSection)
        }
        
    }
    
    @ViewBuilder
    private var DeviceInfoView: some View {
        let text = "\(UIDevice.current.name)" +
        " (\(UIDevice.current.systemVersion)" +
        " - \(Bundle.main.infoDictionary?["DTSDKBuild"] as? String ?? "Unknown"))"
        
        AboutItem(iconName: "ipad.and.iphone", text: text)
    }
    
    @ViewBuilder
    private var ApplicationInfoView: some View {
        let text = "\(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "")" +
        " \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")" +
        " (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))"
        
        AboutItem(iconName: "apple.logo", text: text)
    }
    
    @ViewBuilder
    private var ClockInfoView: some View {
        AboutItem(iconName: "clock",
                  text: ISO8601DateFormatter().string(from: Date()))
    }
    
    @ViewBuilder
    private var InternetAccessInfoView: some View {
        AboutItem(iconName: internetAccesStatusIcon,
                  iconColor: internetAccesStatusColor,
                  text: "Internet access")
    }
}

#Preview {
    AboutView(internetAccesStatusIcon: "wifi",
              internetAccesStatusColor: .blue)
}
