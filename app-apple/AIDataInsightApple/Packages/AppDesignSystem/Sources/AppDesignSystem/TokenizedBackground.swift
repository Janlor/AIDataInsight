import SwiftUI

/// 为页面统一应用设计系统背景色和主文本色。
public struct TokenizedBackground: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .background(AppColor.Background.primary.color)
            .foregroundStyle(AppColor.Label.primary.color)
    }
}

public extension View {
    /// 页面根视图使用的默认设计系统背景。
    func tokenizedBackground() -> some View {
        modifier(TokenizedBackground())
    }
}
