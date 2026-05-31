//
//  AIDataInsightAppleApp.swift
//  AIDataInsightApple
//
//  Created by Janlor on 5/19/26.
//

import SwiftUI

@main
struct AIDataInsightAppleApp: App {
    /// 应用级依赖容器。UI 测试模式下会切到预览仓库，避免依赖真实后端和钥匙串状态。
    @State private var appEnvironment = AppRuntimeEnvironment(
        usePreviewRepositories: CommandLine.arguments.contains("--ui-testing")
    )

    var body: some Scene {
        AppScene(environment: appEnvironment)
    }
}
