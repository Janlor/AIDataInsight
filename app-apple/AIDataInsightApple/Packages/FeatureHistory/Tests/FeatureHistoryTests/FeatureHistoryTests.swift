import Testing
import AppContracts
import Foundation
@testable import FeatureHistory

@MainActor
@Test func historyStoreDeletesConversation() {
    let store = HistoryStore(conversations: [
        HistoryConversationViewState(id: "1", title: "A"),
        HistoryConversationViewState(id: "2", title: "B"),
    ])

    store.delete(id: "1")
    #expect(store.conversations.map(\.id) == ["2"])
}

@MainActor
@Test func historyStoreLoadsAndGroupsRecords() async {
    let store = HistoryStore(repository: PreviewHistoryRepository())

    await store.loadFirstPage()

    #expect(store.state.groups.isEmpty == false)
    #expect(store.conversations.first?.title == "本月销售额趋势")
}

@MainActor
@Test func deletingSelectedHistoryClearsSelection() async {
    let store = HistoryStore(repository: StaticHistoryRepository(records: [
        HistoryRecordContract(id: 7, name: "A", updateTime: ISO8601DateFormatter().string(from: .now), detailList: nil),
    ]))
    await store.loadFirstPage()
    store.select(historyID: 7)

    let deletedSelected = await store.delete(historyID: 7)

    #expect(deletedSelected)
    #expect(store.selectedID == nil)
    #expect(store.conversations.isEmpty)
}

@MainActor
@Test func historyStoreRetriesAfterLoadFailure() async {
    let repository = FlakyHistoryRepository(records: [
        HistoryRecordContract(id: 8, name: "Recovered", updateTime: ISO8601DateFormatter().string(from: .now), detailList: nil),
    ])
    let store = HistoryStore(repository: repository)

    await store.loadFirstPage()

    #expect(store.state.errorMessage == "历史记录加载失败")
    #expect(store.conversations.isEmpty)

    await store.retryLoading()

    #expect(store.state.errorMessage == nil)
    #expect(store.conversations.map(\.title) == ["Recovered"])
}

@MainActor
@Test func historyStoreKeepsRecordsWithoutTimestamp() async {
    let store = HistoryStore(repository: StaticHistoryRepository(records: [
        HistoryRecordContract(id: 9, name: "Untimed", detailList: nil),
    ]))

    await store.loadFirstPage()

    #expect(store.conversations.map(\.title) == ["Untimed"])
}

@MainActor
@Test func historyStoreClearsCachedData() async {
    let store = HistoryStore(repository: StaticHistoryRepository(records: [
        HistoryRecordContract(id: 10, name: "Cached", updateTime: ISO8601DateFormatter().string(from: .now), detailList: nil),
    ]))
    await store.loadFirstPage()
    store.select(historyID: 10)

    store.clearCachedData()

    #expect(store.conversations.isEmpty)
    #expect(store.selectedID == nil)
    #expect(store.state.currentPage == 0)
    #expect(store.state.hasMore)
}

private struct StaticHistoryRepository: HistoryRepository {
    let records: [HistoryRecordContract]

    func loadHistoryPage(currentPage: Int, pageSize: Int) async throws -> RecordPageContract {
        RecordPageContract(currentPage: currentPage, pageSize: pageSize, total: records.count, pages: 1, cacheKey: nil, records: records)
    }

    func deleteHistory(historyId: Int) async throws {}

    func deleteAllHistory() async throws {}
}

private actor FlakyHistoryRepository: HistoryRepository {
    private let records: [HistoryRecordContract]
    private var shouldFail = true

    init(records: [HistoryRecordContract]) {
        self.records = records
    }

    func loadHistoryPage(currentPage: Int, pageSize: Int) async throws -> RecordPageContract {
        if shouldFail {
            shouldFail = false
            throw TestError.loadFailed
        }
        return RecordPageContract(currentPage: currentPage, pageSize: pageSize, total: records.count, pages: 1, cacheKey: nil, records: records)
    }

    func deleteHistory(historyId: Int) async throws {}

    func deleteAllHistory() async throws {}
}

private enum TestError: Error {
    case loadFailed
}
