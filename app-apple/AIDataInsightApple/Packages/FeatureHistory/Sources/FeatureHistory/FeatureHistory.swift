import AppContracts
import AppDesignSystem
import AppNetworking
import Foundation
import Observation
import SwiftUI

public struct HistoryConversationViewState: Identifiable, Equatable, Sendable {
    public let id: String
    public let remoteID: Int?
    public let title: String
    public let displayTime: String
    public let updatedAt: Date

    public init(id: String, remoteID: Int? = nil, title: String, displayTime: String = "", updatedAt: Date = .distantPast) {
        self.id = id
        self.remoteID = remoteID
        self.title = title
        self.displayTime = displayTime
        self.updatedAt = updatedAt
    }
}

public struct HistoryGroupViewState: Identifiable, Equatable, Sendable {
    public let id: HistorySectionKindContract
    public let title: String
    public let conversations: [HistoryConversationViewState]

    public init(id: HistorySectionKindContract, title: String, conversations: [HistoryConversationViewState]) {
        self.id = id
        self.title = title
        self.conversations = conversations
    }
}

public struct HistoryViewState: Equatable, Sendable {
    public var groups: [HistoryGroupViewState]
    public var selectedID: Int?
    public var currentPage: Int
    public var pageSize: Int
    public var hasMore: Bool
    public var isLoading: Bool
    public var isMutating: Bool
    public var errorMessage: String?

    public init(
        groups: [HistoryGroupViewState] = [],
        selectedID: Int? = nil,
        currentPage: Int = 0,
        pageSize: Int = 20,
        hasMore: Bool = true,
        isLoading: Bool = false,
        isMutating: Bool = false,
        errorMessage: String? = nil
    ) {
        self.groups = groups
        self.selectedID = selectedID
        self.currentPage = currentPage
        self.pageSize = pageSize
        self.hasMore = hasMore
        self.isLoading = isLoading
        self.isMutating = isMutating
        self.errorMessage = errorMessage
    }
}

public protocol HistoryRepository: Sendable {
    func loadHistoryPage(currentPage: Int, pageSize: Int) async throws -> RecordPageContract
    func deleteHistory(historyId: Int) async throws
    func deleteAllHistory() async throws
}

public struct RemoteHistoryRepository: HistoryRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func loadHistoryPage(currentPage: Int, pageSize: Int) async throws -> RecordPageContract {
        let envelope = try await client.send(
            HTTPRequest(path: "/history/page", queryItems: [
                HTTPQueryItem(name: "currentPage", value: String(currentPage)),
                HTTPQueryItem(name: "pageSize", value: String(pageSize)),
            ]),
            as: RecordPageContract.self
        )
        return envelope.data ?? RecordPageContract(currentPage: currentPage, pageSize: pageSize, total: 0, pages: 0, cacheKey: nil, records: [])
    }

    public func deleteHistory(historyId: Int) async throws {
        _ = try await client.send(
            HTTPRequest(path: "/history/delete", queryItems: [HTTPQueryItem(name: "historyId", value: String(historyId))]),
            as: EmptyContract.self
        )
    }

    public func deleteAllHistory() async throws {
        _ = try await client.send(HTTPRequest(path: "/history/deleteAll"), as: EmptyContract.self)
    }
}

@MainActor
@Observable
public final class HistoryStore {
    public private(set) var state: HistoryViewState
    private let repository: HistoryRepository
    private var records: [HistoryRecordContract]

    public init(
        conversations: [HistoryConversationViewState] = [],
        state: HistoryViewState? = nil,
        repository: HistoryRepository = PreviewHistoryRepository()
    ) {
        let initialRecords = conversations.map {
            HistoryRecordContract(id: $0.remoteID ?? Int($0.id), name: $0.title, updateTime: ISO8601DateFormatter().string(from: $0.updatedAt), detailList: nil)
        }
        self.repository = repository
        self.records = initialRecords
        self.state = state ?? HistoryViewState(groups: HistoryStore.group(records: initialRecords))
    }

    public var conversations: [HistoryConversationViewState] {
        state.groups.flatMap(\.conversations)
    }

    public var selectedID: Int? {
        state.selectedID
    }

    public func loadFirstPage() async {
        await load(page: 1, replacing: true)
    }

    public func retryLoading() async {
        let nextPage = conversations.isEmpty ? 1 : state.currentPage + 1
        await load(page: nextPage, replacing: conversations.isEmpty)
    }

    public func loadNextPageIfNeeded(currentItemID: String?) async {
        guard state.hasMore, state.isLoading == false else {
            return
        }
        guard currentItemID == conversations.last?.id else {
            return
        }
        await load(page: state.currentPage + 1, replacing: false)
    }

    public func select(historyID: Int) {
        state.selectedID = historyID
    }

    public func clearSelection() {
        state.selectedID = nil
    }

    public func clearCachedData() {
        records.removeAll()
        state.groups.removeAll()
        state.selectedID = nil
        state.currentPage = 0
        state.hasMore = true
        state.errorMessage = nil
    }

    public func delete(id: String) {
        if let remoteID = Int(id) {
            records.removeAll { $0.id == remoteID }
        }
        state.groups = HistoryStore.group(records: records)
    }

    public func delete(historyID: Int) async -> Bool {
        state.isMutating = true
        state.errorMessage = nil
        defer { state.isMutating = false }
        do {
            try await repository.deleteHistory(historyId: historyID)
            records.removeAll { $0.id == historyID }
            state.groups = HistoryStore.group(records: records)
            if state.selectedID == historyID {
                state.selectedID = nil
                return true
            }
            return false
        } catch {
            state.errorMessage = "删除历史记录失败"
            return false
        }
    }

    public func deleteAll() async -> Bool {
        state.isMutating = true
        state.errorMessage = nil
        defer { state.isMutating = false }
        do {
            try await repository.deleteAllHistory()
            records.removeAll()
            state.groups.removeAll()
            state.selectedID = nil
            state.hasMore = false
            return true
        } catch {
            state.errorMessage = "清空历史记录失败"
            return false
        }
    }

    private func load(page: Int, replacing: Bool) async {
        state.isLoading = true
        state.errorMessage = nil
        defer { state.isLoading = false }
        do {
            let pageResult = try await repository.loadHistoryPage(currentPage: page, pageSize: state.pageSize)
            let incoming = pageResult.records ?? []
            records = replacing ? incoming : records + incoming
            state.currentPage = pageResult.currentPage ?? page
            state.pageSize = pageResult.pageSize ?? state.pageSize
            state.hasMore = state.currentPage < (pageResult.pages ?? state.currentPage)
            state.groups = HistoryStore.group(records: records)
        } catch {
            state.errorMessage = "历史记录加载失败"
        }
    }

    private static func group(records: [HistoryRecordContract], now: Date = .now) -> [HistoryGroupViewState] {
        let items = records.compactMap { record -> (kind: HistorySectionKindContract, item: HistoryConversationViewState)? in
            guard record.id != nil || record.name?.isEmpty == false else {
                return nil
            }
            let date = DateParser.parse(record.updateTime ?? record.createTime) ?? now
            let kind = sectionKind(for: date, now: now)
            return (kind, HistoryConversationViewState(
                id: record.id.map(String.init) ?? UUID().uuidString,
                remoteID: record.id,
                title: record.name?.isEmpty == false ? record.name! : "未命名会话",
                displayTime: displayTime(for: date, kind: kind),
                updatedAt: date
            ))
        }

        return HistorySectionKindContract.allCases.compactMap { kind in
            let conversations = items
                .filter { $0.kind == kind }
                .map(\.item)
                .sorted { $0.updatedAt > $1.updatedAt }
            guard conversations.isEmpty == false else {
                return nil
            }
            return HistoryGroupViewState(id: kind, title: kind.title, conversations: conversations)
        }
    }

    private static func sectionKind(for date: Date, now: Date) -> HistorySectionKindContract {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) {
            return .today
        }
        let components = calendar.dateComponents([.year, .month], from: date)
        let nowComponents = calendar.dateComponents([.year, .month], from: now)
        if components.year == nowComponents.year, components.month == nowComponents.month {
            return .thisMonth
        }
        return .other
    }

    private static func displayTime(for date: Date, kind: HistorySectionKindContract) -> String {
        let formatter = DateFormatter()
        switch kind {
        case .today:
            formatter.dateFormat = "HH:mm"
        case .thisMonth:
            formatter.dateFormat = "MM-dd"
        case .other:
            formatter.dateFormat = "yyyy-MM-dd"
        }
        return formatter.string(from: date)
    }
}

public struct HistorySidebar: View {
    @Bindable private var store: HistoryStore
    @State private var hoveredConversationID: Int?
    private let showsTitle: Bool
    private let account: AccountDisplayState
    private let onNewChat: () -> Void
    private let onSelect: (Int) -> Void
    private let onDeletedSelected: () -> Void
    private let onOpenSetting: () -> Void
    private let onOpenPrivacy: () -> Void
    private let onLogout: () -> Void

    public init(
        store: HistoryStore,
        showsTitle: Bool = true,
        account: AccountDisplayState = .placeholder,
        onNewChat: @escaping () -> Void = {},
        onSelect: @escaping (Int) -> Void = { _ in },
        onDeletedSelected: @escaping () -> Void = {},
        onOpenSetting: @escaping () -> Void = {},
        onOpenPrivacy: @escaping () -> Void = {},
        onLogout: @escaping () -> Void = {}
    ) {
        self.store = store
        self.showsTitle = showsTitle
        self.account = account
        self.onNewChat = onNewChat
        self.onSelect = onSelect
        self.onDeletedSelected = onDeletedSelected
        self.onOpenSetting = onOpenSetting
        self.onOpenPrivacy = onOpenPrivacy
        self.onLogout = onLogout
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                if showsTitle {
                    HStack {
                        Text("AI数据分析助手")
                            .font(.headline)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
            .padding(14)

            Divider()
            
            Spacer()

            List(selection: Binding(
                get: { store.state.selectedID },
                set: { value in
                    guard let value else {
                        store.clearSelection()
                        return
                    }
                    store.select(historyID: value)
                    onSelect(value)
                }
            )) {
                if store.state.isLoading, store.conversations.isEmpty {
                    ProgressView()
                        .listRowBackground(AppColor.GroupedBackground.primary.color)
                }

                if let errorMessage = store.state.errorMessage {
                    errorRow(errorMessage)
                        .listRowBackground(AppColor.GroupedBackground.primary.color)
                }

                ForEach(store.state.groups) { group in
                    Section(group.title) {
                        ForEach(group.conversations) { conversation in
                            row(conversation)
                                .tag(conversation.remoteID)
                                .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                                .listRowBackground(AppColor.GroupedBackground.primary.color)
#if os(macOS)
                                .contextMenu {
                                    deleteMenuItem(for: conversation)
                                }
#endif
                                .onAppear {
                                    Task {
                                        await store.loadNextPageIfNeeded(currentItemID: conversation.id)
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(AppColor.GroupedBackground.primary.color)
            .refreshable {
                await store.loadFirstPage()
            }

            Divider()

            Button {
                onOpenSetting()
            } label: {
                HStack(spacing: 10) {
                    accountLabel
                    Spacer()
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .foregroundStyle(AppColor.Label.secondary.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("history-account-settings-button")
            .padding(12)
        }
        .navigationTitle(navigationTitle)
        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        .background(AppColor.GroupedBackground.primary.color)
        .accessibilityIdentifier("history-sidebar")
        .task {
            if store.conversations.isEmpty {
                await store.loadFirstPage()
            }
        }
    }

    private var accountLabel: some View {
        HStack(spacing: 10) {
            AccountInitialsAvatar(account: account, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.subheadline)
                if let secondaryText = account.secondaryText {
                    Text(secondaryText)
                        .font(.caption)
                        .foregroundStyle(AppColor.Label.secondary.color)
                }
            }
        }
    }

    private var navigationTitle: String {
#if os(macOS)
        showsTitle ? "AI数据分析助手" : ""
#else
        ""
#endif
    }

    private func errorRow(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(AppColor.Status.mark.color)

            Button {
                Task {
                    await store.retryLoading()
                }
            } label: {
                Label("重试", systemImage: "arrow.clockwise")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .disabled(store.state.isLoading)
            .accessibilityIdentifier("history-retry-button")
        }
        .padding(.vertical, 6)
    }

    private func row(_ conversation: HistoryConversationViewState) -> some View {
        let isSelected = conversation.remoteID == store.state.selectedID
        let isHovered = conversation.remoteID == hoveredConversationID
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.title)
                    .lineLimit(1)
                    .font(.subheadline)
                if conversation.displayTime.isEmpty == false {
                    Text(conversation.displayTime)
                        .font(.caption)
                        .foregroundStyle(AppColor.Label.secondary.color)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let remoteID = conversation.remoteID else {
                return
            }
            store.select(historyID: remoteID)
            onSelect(remoteID)
        }
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColor.Accent.primary.color.opacity(0.14))
            } else if isHovered {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColor.GroupedBackground.tertiary.color)
            }
        }
        .onHover { isHovering in
            hoveredConversationID = isHovering ? conversation.remoteID : nil
        }
        .accessibilityIdentifier(conversation.remoteID.map { "history-row-\($0)" } ?? "history-row-\(conversation.id)")
        .contextMenu {
            deleteMenuItem(for: conversation)
        }
    }

    private func deleteMenuItem(for conversation: HistoryConversationViewState) -> some View {
        Button(role: .destructive) {
            delete(conversation)
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    private func delete(_ conversation: HistoryConversationViewState) {
        guard let remoteID = conversation.remoteID else {
            return
        }
        Task {
            let deletedSelected = await store.delete(historyID: remoteID)
            if deletedSelected {
                onDeletedSelected()
            }
        }
    }
}

private enum DateParser {
    static func parse(_ string: String?) -> Date? {
        guard let string, string.isEmpty == false else {
            return nil
        }
        if let date = ISO8601DateFormatter().date(from: string) {
            return date
        }
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
}

private extension HistorySectionKindContract {
    var title: String {
        switch self {
        case .today:
            "今天"
        case .thisMonth:
            "本月"
        case .other:
            "其它"
        }
    }
}

public struct PreviewHistoryRepository: HistoryRepository {
    public init() {}

    public func loadHistoryPage(currentPage: Int, pageSize: Int) async throws -> RecordPageContract {
        let formatter = ISO8601DateFormatter()
        let now = Date()
        return RecordPageContract(
            currentPage: currentPage,
            pageSize: pageSize,
            total: 4,
            pages: 1,
            cacheKey: nil,
            records: [
                HistoryRecordContract(id: 100, name: "本月销售额趋势", updateTime: formatter.string(from: now), detailList: nil),
                HistoryRecordContract(id: 101, name: "各组织库存吨数", updateTime: formatter.string(from: now.addingTimeInterval(-3600)), detailList: nil),
                HistoryRecordContract(id: 102, name: "客户应收账款分析", updateTime: formatter.string(from: now.addingTimeInterval(-86400 * 3)), detailList: nil),
                HistoryRecordContract(id: 103, name: "采购金额月度对比", updateTime: formatter.string(from: now.addingTimeInterval(-86400 * 35)), detailList: nil),
            ]
        )
    }

    public func deleteHistory(historyId: Int) async throws {}

    public func deleteAllHistory() async throws {}
}
