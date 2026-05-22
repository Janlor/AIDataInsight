//
//  AppEnvironmentValues.swift
//  LibraryBasics
//
//  Created by OpenAI on 2025/2/14.
//

import Foundation
import BaseEnv

enum AppEnvironmentValues {
    private static let mockBaseURLString = "https://m1.apifoxmock.com/m1/3174267-1700689-default"
    private static let localBaseURLString = "http://127.0.0.1:3000"

    static func oauthAppId(env: EnvInfo.EnvType) -> String {
        switch env {
        case .appStore, .pre:
            return ""
        default:
            return ""
        }
    }

    static func oauthAppSecret(env: EnvInfo.EnvType) -> String {
        switch env {
        case .appStore, .pre:
            return ""
        default:
            return ""
        }
    }

    static func oauthAppSalt(env: EnvInfo.EnvType) -> String {
        switch env {
        case .appStore, .pre:
            return ""
        default:
            return ""
        }
    }

    static func authURL(env: EnvInfo.EnvType) -> URL? {
        switch env {
        case .unknow:
            return nil
        case .appStore:
            return URL(string: "")
        case .pre:
            return URL(string: "")
        case .staging:
            return URL(string: "")
        case .uat:
            return URL(string: "")
        case .sit:
            return URL(string: "")
        case .dev:
            return URL(string: "")
        }
    }

    static func baseURL(env: EnvInfo.EnvType, target: CommonTarget.TargetType) -> URL {
        switch env {
        case .pre:
            switch target {
            default:
                return URL(string: mockBaseURLString)!
            }
        case .staging, .uat, .sit, .dev:
            return URL(string: localBaseURLString)!
        default:
            switch target {
            default:
                return URL(string: localBaseURLString)!
            }
        }
    }

    static func uploadURL(env: EnvInfo.EnvType) -> URL {
        switch env {
        case .pre:
            return URL(string: "")!
        case .uat:
            return URL(string: "")!
        case .sit:
            return URL(string: "")!
        case .dev:
            return URL(string: "")!
        default:
            return URL(string: "")!
        }
    }

    static func updatePath(target: CommonTarget.TargetType) -> String {
        switch target {
        default:
            return "/download/iOSAppVersionConfigure.json"
        }
    }

    static func privacyPolicyURL(target: CommonTarget.TargetType) -> String {
        switch target {
        default:
            return "https://example.com.cn/privacypolicy"
        }
    }

    static func webHost(env: EnvInfo.EnvType, target: CommonTarget.TargetType) -> String {
        switch target {
        default:
            return hbHost(env: env)
        }
    }

    private static func hbHost(env: EnvInfo.EnvType) -> String {
        switch env {
        case .unknow:
            return ""
        case .appStore:
            return ""
        case .pre:
            return ""
        case .staging:
            return ""
        case .uat:
            return ""
        case .sit:
            return ""
        case .dev:
            return ""
        }
    }
}
