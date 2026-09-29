//
//  DestructiveAlertViewModifier.swift
//  
//
//  Created by Hrvoje Hajduković on 19.09.2025..
//

import SwiftUI

public struct DestructiveAlertViewModifier: ViewModifier {
    @Binding var isShowingAlert: Bool
    let title: String
    let message: String
    let action: () -> Void

    public func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isShowingAlert) {
                Button(LS.Alert.btnCancel, role: .cancel) {}
                Button(LS.Alert.btnDelete, role: .destructive) {
                    action()
                }
            } message: {
                Text(message)
            }
    }
}

extension View {
    public func destructiveAlertViewModifier(
        isShowingAlert: Binding<Bool>,
        title: String,
        message: String,
        action: @escaping () -> Void
    ) -> some View {
        self.modifier(
            DestructiveAlertViewModifier(
                isShowingAlert: isShowingAlert,
                title: title,
                message: message,
                action: action
            )
        )
    }
}
