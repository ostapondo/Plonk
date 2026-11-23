import SwiftUI

enum AnnotationColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, black, white

    var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    var paint: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .black: return .black
        case .white: return .white
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .red: return .annotationRed
        case .orange: return .annotationOrange
        case .yellow: return .annotationYellow
        case .green: return .annotationGreen
        case .blue: return .annotationBlue
        case .purple: return .annotationPurple
        case .black: return .annotationBlack
        case .white: return .annotationWhite
        }
    }
}
