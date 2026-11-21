import Foundation

extension LocalizedStringResource {
    static let annotationDefaultStyles = Self.key("annotation.defaultStyles")
    static let annotationColors = Self.key("annotation.colors")
    static let annotationPixelUnit = Self.key("annotation.pixelUnit")
    static let annotationWidthDragHelp = Self.key("annotation.widthDragHelp")

    static func annotationWidthValue(_ width: Int) -> Self {
        Self.key("annotation.widthValue \(width)")
    }

    static func annotationWidthRange(_ minimum: Int, _ maximum: Int) -> Self {
        Self.key("annotation.widthRange \(minimum) \(maximum)")
    }

    static let annotationRed = Self.key("annotation.red")
    static let annotationOrange = Self.key("annotation.orange")
    static let annotationYellow = Self.key("annotation.yellow")
    static let annotationGreen = Self.key("annotation.green")
    static let annotationBlue = Self.key("annotation.blue")
    static let annotationPurple = Self.key("annotation.purple")
    static let annotationBlack = Self.key("annotation.black")
    static let annotationWhite = Self.key("annotation.white")
}
