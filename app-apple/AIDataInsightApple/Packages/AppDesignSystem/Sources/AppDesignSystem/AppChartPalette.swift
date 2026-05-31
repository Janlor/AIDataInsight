/// 图表配色 token，order 决定多系列图表的取色顺序。
public enum AppChartPalette {
    public static let order = ["blue", "cyan", "mint", "green", "purple", "orange", "coral"]

    public static let blue = AppColorToken(lightHex: "#2F7BFF", darkHex: "#2F7BFF")
    public static let cyan = AppColorToken(lightHex: "#18B8FF", darkHex: "#18B8FF")
    public static let mint = AppColorToken(lightHex: "#33E0C4", darkHex: "#33E0C4")
    public static let green = AppColorToken(lightHex: "#3DDC97", darkHex: "#3DDC97")
    public static let purple = AppColorToken(lightHex: "#8B7CFF", darkHex: "#8B7CFF")
    public static let orange = AppColorToken(lightHex: "#FFB547", darkHex: "#FFB547")
    public static let coral = AppColorToken(lightHex: "#FF6B6B", darkHex: "#FF6B6B")
}
