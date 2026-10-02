import SwiftUI

enum PrototypeTheme {
    static let background = Color(red: 0.34, green: 0.34, blue: 0.33)
    static let foreground = Color.white
    static let muted = Color.white.opacity(0.55)
    static let accent = Color("AccentColor")
    static let success = Color("SuccessColor")
}

enum PrototypeFont {
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .thin: name = "Inter-Regular_Thin"
        case .ultraLight: name = "Inter-Regular_ExtraLight"
        case .light: name = "Inter-Regular_Light"
        case .medium: name = "Inter-Regular_Medium"
        case .semibold: name = "Inter-Regular_SemiBold"
        case .bold: name = "Inter-Regular_Bold"
        case .heavy: name = "Inter-Regular_ExtraBold"
        case .black: name = "Inter-Regular_Black"
        default: name = "Inter-Regular"
        }
        return .custom(name, size: size)
    }

    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        inter(size, weight: weight)
    }
}
