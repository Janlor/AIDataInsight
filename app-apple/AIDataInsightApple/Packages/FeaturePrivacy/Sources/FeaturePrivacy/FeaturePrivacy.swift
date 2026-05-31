import AppContracts
import SwiftUI

/// 隐私政策单个章节的视图状态。
public struct PrivacyPolicySectionState: Equatable, Sendable, Identifiable {
    public let id: String
    public let heading: String
    public let paragraphs: [String]

    public init(id: String, heading: String, paragraphs: [String]) {
        self.id = id
        self.heading = heading
        self.paragraphs = paragraphs
    }
}

/// 隐私政策页面状态，由契约模型转换为可渲染的章节列表。
public struct PrivacyPolicyState: Equatable, Sendable {
    public let title: String
    public let updatedAt: String
    public let sections: [PrivacyPolicySectionState]

    public init(
        title: String = PrivacyPolicyContract.current.title,
        updatedAt: String = PrivacyPolicyContract.current.updatedAt,
        sections: [PrivacyPolicySectionState] = PrivacyPolicyState.sections(from: PrivacyPolicyContract.current)
    ) {
        self.title = title
        self.updatedAt = updatedAt
        self.sections = sections
    }

    public init(contract: PrivacyPolicyContract) {
        self.init(
            title: contract.title,
            updatedAt: contract.updatedAt,
            sections: PrivacyPolicyState.sections(from: contract)
        )
    }

    public static func sections(from contract: PrivacyPolicyContract) -> [PrivacyPolicySectionState] {
        // 使用序号参与 id，避免不同章节标题重复时 ForEach 标识冲突。
        contract.sections.enumerated().map { index, section in
            PrivacyPolicySectionState(
                id: "\(index)-\(section.heading)",
                heading: section.heading,
                paragraphs: section.paragraphs
            )
        }
    }
}

/// 隐私政策页面，供登录页、设置页和 macOS Settings 复用。
public struct PrivacyScreen: View {
    public let state: PrivacyPolicyState

    public init(state: PrivacyPolicyState = PrivacyPolicyState()) {
        self.state = state
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(state.title)
                        .font(.largeTitle.bold())
                    Text("更新日期：\(state.updatedAt)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(state.sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.heading)
                            .font(.headline)
                        ForEach(section.paragraphs, id: \.self) { paragraph in
                            Text(paragraph)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle(state.title)
    }
}
