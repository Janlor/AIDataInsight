//
//  AppScene.swift
//  AIDataInsightApple
//
//  Created by Codex on 5/19/26.
//

import SwiftUI
#if os(macOS)
import FeaturePrivacy
import FeatureSetting
#endif

struct AppScene: Scene {
    let environment: AppRuntimeEnvironment

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
        }
#if os(macOS)
        .defaultSize(width: 1280, height: 820)
#endif
        .commands {
            AppCommands()
        }
#if os(macOS)
        // macOS 使用系统 Settings 场景承载设置页；iOS/iPadOS 则由 RootView 以 sheet 展示。
        Settings {
            MacSettingsView(environment: environment)
        }
#endif
    }
}

#if os(macOS)
private struct MacSettingsView: View {
    @Bindable var environment: AppRuntimeEnvironment
    /// 设置页内部的导航路径，目前用于从“设置”进入“隐私政策”。
    @State private var path: [MacSettingsRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            SettingScreen(
                store: environment.settingStore,
                onOpenPrivacy: {
                    path.append(.privacy)
                },
                showsLogoutAction: false
            )
            .navigationDestination(for: MacSettingsRoute.self) { route in
                switch route {
                case .privacy:
                    PrivacyScreen()
                }
            }
        }
        .frame(minWidth: 500, minHeight: 540)
    }
}

private enum MacSettingsRoute: Hashable {
    case privacy
}
#endif
