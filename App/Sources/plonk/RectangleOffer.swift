import SwiftUI

// The one moment a Rectangle user is looking at this app and does not yet know
// their setup can come with them.
//
// The import button lives on the Shortcuts page, which is where it belongs and
// also where nobody goes first. Somebody arriving from Rectangle lands on Home,
// and nothing there said the button existed — so the offer comes to them, on
// the page they are already on, and only when there is actually a Rectangle
// setup on this Mac to take.
//
// Shown once. Taking it or turning it down both settle it for good, because an
// offer that returns every launch is an advert.

struct RectangleOffer: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "arrow.down.left.and.arrow.up.right.rectangle")
                .font(.system(size: 15))
                .foregroundStyle(model.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(.homeRectangleTitle).font(.callout.weight(.medium))
                Text(.homeRectangleDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 9) {
                    Button(String(localized: .homeRectangleTake)) {
                        model.actions?.importFromRectangle()
                    }
                    Button(String(localized: .homeRectangleNotNow)) {
                        model.actions?.dismissRectangleOffer()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    Spacer()
                    // The rest of the story: the URL scheme, and which keys are
                    // deliberately not taken.
                    Button(String(localized: .homeRectangleMore)) {
                        model.selectedPage = "shortcuts"
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
                .padding(.top, 5)
            }
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 12).fill(model.accent.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(model.accent.opacity(0.28)))
    }
}
