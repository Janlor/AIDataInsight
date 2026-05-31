import AppContracts
import Foundation
import SwiftData

/// 用户偏好记录，仅保存非敏感、小体量的本地设置。
public struct UserPreferenceRecord: Equatable, Sendable {
    public let key: String
    public var value: String
    public var updatedAt: Date

    public init(key: String, value: String, updatedAt: Date = .now) {
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }
}

/// 持久化边界说明：敏感会话进 Keychain，普通缓存进 SwiftData。
public enum PersistenceBoundary {
    public static let sensitiveSessionStorage = "Keychain"
    public static let nonSensitiveCacheStorage = "SwiftData"
}

/// SwiftData schema 入口，集中声明当前 App 使用的模型集合。
public enum AppPersistenceSchema {
    public static let version = "0.1.0"

    public static var schema: Schema {
        Schema([
            CachedHistoryRecordModel.self,
            CachedHistoryDetailModel.self,
            CachedTemplateQuestionSetModel.self,
            UserPreferenceModel.self,
        ])
    }
}

/// ModelContainer 工厂，生产环境和测试环境通过参数选择磁盘或内存存储。
public enum AppModelContainerFactory {
    public static func make(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: AppPersistenceSchema.schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try ModelContainer(
            for: AppPersistenceSchema.schema,
            configurations: [configuration]
        )
    }

    public static func makeInMemory() throws -> ModelContainer {
        try make(isStoredInMemoryOnly: true)
    }
}

/// 历史会话缓存模型，和明细模型使用级联删除关系。
@Model
public final class CachedHistoryRecordModel {
    @Attribute(.unique) public var cacheID: String
    public var remoteID: Int?
    public var name: String
    public var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \CachedHistoryDetailModel.record)
    public var details: [CachedHistoryDetailModel]

    public init(
        cacheID: String,
        remoteID: Int?,
        name: String,
        updatedAt: Date = .now,
        details: [CachedHistoryDetailModel] = []
    ) {
        self.cacheID = cacheID
        self.remoteID = remoteID
        self.name = name
        self.updatedAt = updatedAt
        self.details = details
    }
}

/// 历史明细缓存模型，保留原始枚举值以降低本地 schema 迁移成本。
@Model
public final class CachedHistoryDetailModel {
    @Attribute(.unique) public var cacheID: String
    public var remoteID: Int?
    public var historyID: Int?
    public var detailTypeRawValue: String?
    public var contentTypeRawValue: String?
    public var content: String?
    public var sortIndex: Int
    public var updatedAt: Date
    public var record: CachedHistoryRecordModel?

    public init(
        cacheID: String,
        remoteID: Int?,
        historyID: Int?,
        detailTypeRawValue: String?,
        contentTypeRawValue: String?,
        content: String?,
        sortIndex: Int,
        updatedAt: Date = .now
    ) {
        self.cacheID = cacheID
        self.remoteID = remoteID
        self.historyID = historyID
        self.detailTypeRawValue = detailTypeRawValue
        self.contentTypeRawValue = contentTypeRawValue
        self.content = content
        self.sortIndex = sortIndex
        self.updatedAt = updatedAt
    }
}

/// 推荐问题缓存模型，问题数组以 JSON payload 保存，避免为简单列表建子表。
@Model
public final class CachedTemplateQuestionSetModel {
    @Attribute(.unique) public var cacheKey: String
    public var questionsPayload: Data
    public var updatedAt: Date

    public init(cacheKey: String, questionsPayload: Data, updatedAt: Date = .now) {
        self.cacheKey = cacheKey
        self.questionsPayload = questionsPayload
        self.updatedAt = updatedAt
    }
}

/// 用户偏好 SwiftData 模型。
@Model
public final class UserPreferenceModel {
    @Attribute(.unique) public var key: String
    public var value: String
    public var updatedAt: Date

    public init(key: String, value: String, updatedAt: Date = .now) {
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }
}

/// 历史缓存仓库协议，供未来离线或启动缓存读取复用。
@MainActor
public protocol HistoryCacheRepository {
    func replaceAll(with records: [HistoryRecordContract]) throws
    func list() throws -> [HistoryRecordContract]
    func delete(remoteID: Int) throws
    func clear() throws
}

/// 基于 SwiftData 的历史缓存仓库实现。
@MainActor
public final class SwiftDataHistoryCacheRepository: HistoryCacheRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func replaceAll(with records: [HistoryRecordContract]) throws {
        try clear()
        for record in records {
            let model = CachedHistoryRecordModel(contract: record)
            context.insert(model)
            model.details.forEach { context.insert($0) }
        }
        try context.save()
    }

    public func list() throws -> [HistoryRecordContract] {
        let descriptor = FetchDescriptor<CachedHistoryRecordModel>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { record in
            var details = record.details
            if let remoteID = record.remoteID {
                // 显式按 sortIndex 取明细，避免 SwiftData relationship 的默认顺序影响聊天回放。
                let detailDescriptor = FetchDescriptor<CachedHistoryDetailModel>(
                    predicate: #Predicate { detail in
                        detail.historyID == remoteID
                    },
                    sortBy: [SortDescriptor(\.sortIndex)]
                )
                details = try context.fetch(detailDescriptor)
            }
            return record.contract(with: details)
        }
    }

    public func delete(remoteID: Int) throws {
        let id = remoteID
        let descriptor = FetchDescriptor<CachedHistoryRecordModel>(
            predicate: #Predicate { model in
                model.remoteID == id
            }
        )
        for model in try context.fetch(descriptor) {
            context.delete(model)
        }
        try context.save()
    }

    public func clear() throws {
        try context.delete(model: CachedHistoryRecordModel.self)
        try context.save()
    }
}

/// 推荐问题缓存仓库协议。
@MainActor
public protocol TemplateQuestionCacheRepository {
    func save(_ questionSet: TemplateQuestionSetContract, cacheKey: String) throws
    func load(cacheKey: String) throws -> TemplateQuestionSetContract?
    func clear(cacheKey: String) throws
}

/// 基于 SwiftData 的推荐问题缓存仓库实现。
@MainActor
public final class SwiftDataTemplateQuestionCacheRepository: TemplateQuestionCacheRepository {
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(context: ModelContext) {
        self.context = context
    }

    public func save(_ questionSet: TemplateQuestionSetContract, cacheKey: String = "default") throws {
        let payload = try encoder.encode(questionSet.questions)
        if let existing = try fetch(cacheKey: cacheKey) {
            existing.questionsPayload = payload
            existing.updatedAt = .now
        } else {
            context.insert(CachedTemplateQuestionSetModel(cacheKey: cacheKey, questionsPayload: payload))
        }
        try context.save()
    }

    public func load(cacheKey: String = "default") throws -> TemplateQuestionSetContract? {
        try fetch(cacheKey: cacheKey).map {
            TemplateQuestionSetContract(questions: try decoder.decode([String].self, from: $0.questionsPayload))
        }
    }

    public func clear(cacheKey: String = "default") throws {
        if let existing = try fetch(cacheKey: cacheKey) {
            context.delete(existing)
            try context.save()
        }
    }

    private func fetch(cacheKey: String) throws -> CachedTemplateQuestionSetModel? {
        let key = cacheKey
        let descriptor = FetchDescriptor<CachedTemplateQuestionSetModel>(
            predicate: #Predicate { model in
                model.cacheKey == key
            }
        )
        return try context.fetch(descriptor).first
    }
}

/// 用户偏好仓库协议。
@MainActor
public protocol UserPreferenceRepository {
    func save(_ record: UserPreferenceRecord) throws
    func load(key: String) throws -> UserPreferenceRecord?
    func delete(key: String) throws
}

/// 基于 SwiftData 的用户偏好仓库实现。
@MainActor
public final class SwiftDataUserPreferenceRepository: UserPreferenceRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func save(_ record: UserPreferenceRecord) throws {
        if let existing = try fetch(key: record.key) {
            existing.value = record.value
            existing.updatedAt = record.updatedAt
        } else {
            context.insert(UserPreferenceModel(record: record))
        }
        try context.save()
    }

    public func load(key: String) throws -> UserPreferenceRecord? {
        try fetch(key: key).map(\.record)
    }

    public func delete(key: String) throws {
        if let existing = try fetch(key: key) {
            context.delete(existing)
            try context.save()
        }
    }

    private func fetch(key: String) throws -> UserPreferenceModel? {
        let lookupKey = key
        let descriptor = FetchDescriptor<UserPreferenceModel>(
            predicate: #Predicate { model in
                model.key == lookupKey
            }
        )
        return try context.fetch(descriptor).first
    }
}

private extension CachedHistoryRecordModel {
    /// 在契约模型和缓存模型之间转换，cacheID 优先使用远端 id，缺失时生成本地 id。
    convenience init(contract: HistoryRecordContract) {
        let remoteID = contract.id
        let detailModels = (contract.detailList ?? []).enumerated().map { index, detail in
            CachedHistoryDetailModel(contract: detail, sortIndex: index)
        }
        self.init(
            cacheID: remoteID.map { "history-\($0)" } ?? UUID().uuidString,
            remoteID: remoteID,
            name: contract.name ?? "Untitled",
            details: detailModels
        )
        detailModels.forEach { $0.record = self }
    }

    var contract: HistoryRecordContract {
        contract(with: details)
    }

    func contract(with details: [CachedHistoryDetailModel]) -> HistoryRecordContract {
        HistoryRecordContract(
            id: remoteID,
            name: name,
            updateTime: ISO8601DateFormatter().string(from: updatedAt),
            detailList: details
                .sorted { $0.sortIndex < $1.sortIndex }
                .map(\.contract)
        )
    }
}

private extension CachedHistoryDetailModel {
    /// 保存明细在原会话中的顺序，用于恢复聊天列表时稳定排序。
    convenience init(contract: HistoryDetailContract, sortIndex: Int) {
        let remoteID = contract.id
        self.init(
            cacheID: remoteID.map { "history-detail-\($0)" } ?? UUID().uuidString,
            remoteID: remoteID,
            historyID: contract.historyId,
            detailTypeRawValue: contract.type?.rawValue,
            contentTypeRawValue: contract.contentType?.rawValue,
            content: contract.content,
            sortIndex: sortIndex
        )
    }

    var contract: HistoryDetailContract {
        HistoryDetailContract(
            id: remoteID,
            historyId: historyID,
            type: detailTypeRawValue.flatMap(HistoryDetailTypeContract.init(rawValue:)),
            contentType: contentTypeRawValue.flatMap(HistoryContentTypeContract.init(rawValue:)),
            content: content,
            updateTime: ISO8601DateFormatter().string(from: updatedAt)
        )
    }
}

private extension UserPreferenceModel {
    convenience init(record: UserPreferenceRecord) {
        self.init(key: record.key, value: record.value, updatedAt: record.updatedAt)
    }

    var record: UserPreferenceRecord {
        UserPreferenceRecord(key: key, value: value, updatedAt: updatedAt)
    }
}
