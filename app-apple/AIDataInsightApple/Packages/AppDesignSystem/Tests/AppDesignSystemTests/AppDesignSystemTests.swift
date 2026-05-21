import Testing
@testable import AppDesignSystem

@Test func spacingTokensAreStable() {
    #expect(AppSpacing.small == 8)
    #expect(AppSpacing.medium == 16)
    #expect(AppSpacing.large == 24)
}

@Test func accentPrimaryMatchesContractToken() {
    #expect(AppColor.Accent.primary.lightHex == "#2F7BFF")
    #expect(AppColor.Accent.primary.darkHex == "#4C8DFF")
}

@Test func chartPaletteOrderMatchesContractToken() {
    #expect(AppChartPalette.order == ["blue", "cyan", "mint", "green", "purple", "orange", "coral"])
}

@Test func accountDisplayInitialsUseNicknameWords() {
    let account = AccountDisplayState(displayName: "Janlor Lee", secondaryText: "janlor")
    #expect(account.initials == "JL")
    #expect(account.secondaryText == "janlor")
}

@Test func accountDisplayInitialsHandleCompactNames() {
    let account = AccountDisplayState(displayName: "演示账号", secondaryText: "演示账号")
    #expect(account.initials == "演示")
    #expect(account.secondaryText == nil)
}
