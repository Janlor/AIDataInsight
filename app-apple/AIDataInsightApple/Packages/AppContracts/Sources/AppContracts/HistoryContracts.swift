/// 历史明细的角色类型：问题或回答。
public enum HistoryDetailTypeContract: String, Codable, Sendable {
    case question = "1"
    case answer = "2"
}

/// 历史回答内容类型：纯 AI 文本或图表 JSON。
public enum HistoryContentTypeContract: String, Codable, Sendable {
    case ai = "1"
    case chart = "2"
}

/// 历史列表按时间归档后的分区类型。
public enum HistorySectionKindContract: String, Codable, CaseIterable, Sendable {
    case today
    case thisMonth
    case other
}

/// 单条历史对话明细，后端以 type/contentType 区分问题、文本回答和图表回答。
public struct HistoryDetailContract: Codable, Equatable, Sendable {
    public let id: Int?
    public let historyId: Int?
    public let type: HistoryDetailTypeContract?
    public let contentType: HistoryContentTypeContract?
    public let content: String?
    public let isLike: String?
    public let createTime: String?
    public let updateTime: String?

    public init(
        id: Int?,
        historyId: Int?,
        type: HistoryDetailTypeContract?,
        contentType: HistoryContentTypeContract?,
        content: String?,
        isLike: String? = nil,
        createTime: String? = nil,
        updateTime: String? = nil
    ) {
        self.id = id
        self.historyId = historyId
        self.type = type
        self.contentType = contentType
        self.content = content
        self.isLike = isLike
        self.createTime = createTime
        self.updateTime = updateTime
    }

    public init(id: Int?, historyId: Int?, type: HistoryDetailTypeContract?, contentType: HistoryContentTypeContract?, content: String?) {
        self.init(id: id, historyId: historyId, type: type, contentType: contentType, content: content, isLike: nil, createTime: nil, updateTime: nil)
    }
}

/// 一次历史会话记录，包含会话元信息和可选的明细列表。
public struct HistoryRecordContract: Codable, Equatable, Sendable {
    public let id: Int?
    public let name: String?
    public let createId: Int?
    public let updateId: Int?
    public let createName: String?
    public let updateName: String?
    public let createTime: String?
    public let updateTime: String?
    public let detailList: [HistoryDetailContract]?

    public init(
        id: Int?,
        name: String?,
        createId: Int? = nil,
        updateId: Int? = nil,
        createName: String? = nil,
        updateName: String? = nil,
        createTime: String? = nil,
        updateTime: String? = nil,
        detailList: [HistoryDetailContract]?
    ) {
        self.id = id
        self.name = name
        self.createId = createId
        self.updateId = updateId
        self.createName = createName
        self.updateName = updateName
        self.createTime = createTime
        self.updateTime = updateTime
        self.detailList = detailList
    }

    public init(id: Int?, name: String?, detailList: [HistoryDetailContract]?) {
        self.init(id: id, name: name, createId: nil, updateId: nil, createName: nil, updateName: nil, createTime: nil, updateTime: nil, detailList: detailList)
    }
}

/// 历史分页接口返回的页信息。
public struct RecordPageContract: Codable, Equatable, Sendable {
    public let currentPage: Int?
    public let pageSize: Int?
    public let total: Int?
    public let pages: Int?
    public let cacheKey: String?
    public let records: [HistoryRecordContract]?

    public init(currentPage: Int?, pageSize: Int?, total: Int?, pages: Int?, cacheKey: String?, records: [HistoryRecordContract]?) {
        self.currentPage = currentPage
        self.pageSize = pageSize
        self.total = total
        self.pages = pages
        self.cacheKey = cacheKey
        self.records = records
    }
}
