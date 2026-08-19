import SwiftUI

// The Features submenu of the menu bar dropdown: every module with a switch,
// so anything can be turned off without opening the app. The same list the
// Features page draws, read and written through the same config field.
//
// One view rather than one menu item per feature: a menu item closes the menu
// when it is clicked, and a switch that shut the menu after every flip would
// make turning three things off a chore.

struct StatusMenuFeatures: View {
    /// Read when the menu opens, and again after every flip.
    let isOn: (Feature) -> Bool
    let toggle: (Feature, Bool) -> Void

    static let width: CGFloat = 236
    private static let rowHeight: CGFloat = 28
    static var height: CGFloat { CGFloat(Feature.allCases.count) * rowHeight + 8 }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Feature.allCases) { feature in
                row(feature)
            }
        }
        .padding(.vertical, 4)
        .frame(width: Self.width, height: Self.height)
    }

    private func row(_ feature: Feature) -> some View {
        HStack(spacing: 9) {
            Image(systemName: feature.icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(feature.title)
                .font(.system(size: 13))
                .lineLimit(1)
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(get: { isOn(feature) }, set: { toggle(feature, $0) }))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(.horizontal, 14)
        .frame(height: Self.rowHeight)
    }
}
