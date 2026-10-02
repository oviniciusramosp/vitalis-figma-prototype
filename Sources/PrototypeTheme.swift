import SwiftUI
import Observation
import UIKit

enum PrototypeThemeChoice: String, CaseIterable, Identifiable {
    case gray, dark, light

    var id: String { rawValue }
    var title: String {
        switch self {
        case .gray: "Gray"
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    var symbol: String {
        switch self {
        case .gray: "circle.lefthalf.filled"
        case .dark: "moon.fill"
        case .light: "sun.max.fill"
        }
    }

    var colorScheme: ColorScheme { self == .light ? .light : .dark }
    var meshIndex: Float {
        switch self {
        case .gray: 0
        case .dark: 1
        case .light: 2
        }
    }
}

/// The same observed selection feeds the native chrome, content tokens and Metal pass.
@Observable
final class PrototypeAppearance {
    static let shared = PrototypeAppearance()
    static let storageKey = "prototype.appearance.v1"

    var selection: PrototypeThemeChoice {
        didSet {
            UserDefaults.standard.set(selection.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        if ProcessInfo.processInfo.arguments.contains("--reset-theme") {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        }
        selection = PrototypeThemeChoice(rawValue: UserDefaults.standard.string(forKey: Self.storageKey) ?? "") ?? .gray
    }
}

enum PrototypeTheme {
    static var selection: PrototypeThemeChoice { PrototypeAppearance.shared.selection }
    static var colorScheme: ColorScheme { selection.colorScheme }
    static var background: Color {
        switch selection {
        case .gray: Color(red: 0.34, green: 0.34, blue: 0.33)
        case .dark: Color(red: 0.12, green: 0.12, blue: 0.12)
        case .light: Color(red: 0.86, green: 0.86, blue: 0.85)
        }
    }
    static var foreground: Color { selection == .light ? Color(white: 0.12) : .white }
    static var muted: Color { foreground.opacity(selection == .light ? 0.65 : 0.55) }
    static var surface: Color {
        switch selection {
        case .gray: .black.opacity(0.25)
        case .dark: .white.opacity(0.055)
        case .light: .white.opacity(0.48)
        }
    }
    static var listRow: Color { selection == .light ? .white.opacity(0.54) : .white.opacity(0.045) }
    static var headerGray: Color {
        switch selection {
        case .gray: Color(white: 0.40)
        case .dark: Color(white: 0.14)
        case .light: Color(white: 0.86)
        }
    }
    static var panelTint: Color {
        switch selection {
        case .gray: .black.opacity(0.14)
        case .dark: .black.opacity(0.24)
        case .light: Color(white: 0.55).opacity(0.14)
        }
    }
    static var modalTint: Color {
        selection == .light ? Color.white.opacity(0.60) : Color.black.opacity(0.60)
    }
    static var blurStyle: UIBlurEffect.Style {
        selection == .light ? .systemUltraThinMaterialLight : .systemUltraThinMaterialDark
    }
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
