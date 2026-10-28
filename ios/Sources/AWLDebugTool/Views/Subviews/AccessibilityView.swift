import SwiftUI

/// Accessibility module page: appearance and font size of the app. The panel itself keeps the device settings.
struct AccessibilityView: View {
    @Binding var preferredColorScheme: DebugView.AppColorScheme
    @Binding var preferredFontSize: DebugView.AppFontSize

    var body: some View {
        Form {
            ColorSchemeSectionView(preferredColorScheme: $preferredColorScheme)
            FontSizeSectionView(preferredFontSize: $preferredFontSize)
        }
        .panelPage(LS.Settings.accessibility)
    }
}
