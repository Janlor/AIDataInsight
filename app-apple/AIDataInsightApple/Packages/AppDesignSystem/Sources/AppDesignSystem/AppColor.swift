import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct AppColorToken: Equatable, Sendable {
    public let lightHex: String
    public let darkHex: String
    public let elevatedHex: String?

    public init(lightHex: String, darkHex: String, elevatedHex: String? = nil) {
        self.lightHex = lightHex
        self.darkHex = darkHex
        self.elevatedHex = elevatedHex
    }

    public var color: Color {
        Color(light: Color(hex: lightHex), dark: Color(hex: darkHex))
    }

    public var elevatedColor: Color {
        Color(light: Color(hex: lightHex), dark: Color(hex: elevatedHex ?? darkHex))
    }
}

public enum AppColor {
    public enum Accent {
        public static let primary = AppColorToken(lightHex: "#2F7BFF", darkHex: "#4C8DFF", elevatedHex: "#5A97FF")
        public static let secondary = AppColorToken(lightHex: "#1A2F7BFF", darkHex: "#264C8DFF")
    }

    public enum Background {
        public static let primary = AppColorToken(lightHex: "#FFFFFF", darkHex: "#0B1020", elevatedHex: "#131A2A")
        public static let secondary = AppColorToken(lightHex: "#F4F7FB", darkHex: "#151D30", elevatedHex: "#1B2438")
        public static let tertiary = AppColorToken(lightHex: "#FFFFFF", darkHex: "#202B42", elevatedHex: "#2A3652")
    }

    public enum GroupedBackground {
        public static let primary = AppColorToken(lightHex: "#F4F7FB", darkHex: "#0B1020", elevatedHex: "#131A2A")
        public static let secondary = AppColorToken(lightHex: "#FFFFFF", darkHex: "#151D30", elevatedHex: "#1B2438")
        public static let tertiary = AppColorToken(lightHex: "#EEF3FA", darkHex: "#202B42", elevatedHex: "#2A3652")
    }

    public enum Label {
        public static let primary = AppColorToken(lightHex: "#111827", darkHex: "#F9FAFB")
        public static let secondary = AppColorToken(lightHex: "#5B6475", darkHex: "#B8C2D9")
        public static let tertiary = AppColorToken(lightHex: "#8A94A6", darkHex: "#8F9BB3")
        public static let quaternary = AppColorToken(lightHex: "#B2BAC8", darkHex: "#657089")
        public static let quinary = AppColorToken(lightHex: "#D1D5DB", darkHex: "#4B5568")
    }

    public enum Separator {
        public static let `default` = AppColorToken(lightHex: "#E5EAF3", darkHex: "#2B364C")
    }

    public enum Status {
        public static let mark = AppColorToken(lightHex: "#FF5A6B", darkHex: "#FF6B7A")
    }
}

public extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)

        let alpha: Double
        let red: Double
        let green: Double
        let blue: Double

        switch trimmed.count {
        case 8:
            alpha = Double((value & 0xFF000000) >> 24) / 255.0
            red = Double((value & 0x00FF0000) >> 16) / 255.0
            green = Double((value & 0x0000FF00) >> 8) / 255.0
            blue = Double(value & 0x000000FF) / 255.0
        default:
            alpha = 1.0
            red = Double((value & 0xFF0000) >> 16) / 255.0
            green = Double((value & 0x00FF00) >> 8) / 255.0
            blue = Double(value & 0x0000FF) / 255.0
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

private extension Color {
    init(light: Color, dark: Color) {
#if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(dark)
                : NSColor(light)
        })
#else
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
#endif
    }
}
