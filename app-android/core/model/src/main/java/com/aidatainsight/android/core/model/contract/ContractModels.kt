// Generated from docs/cross-platform/contracts. Do not edit by hand.
package com.aidatainsight.android.core.model.contract

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

object MockApiEnvironment {
    /** Apifox mock 环境默认地址，与跨端契约保持一致。 */
    const val DefaultBaseUrl: String = "https://m1.apifoxmock.com/m1/3174267-1700689-default"
}

object AIChatEndpoint {
    /** AI 文本流式输出接口路径。 */
    const val StreamPath: String = "/stream"
}

@Serializable
/** 一个可请求的 API 环境。 */
data class ApiEnvironment(
    val name: String,
    val baseUrl: String,
    val description: String? = null,
)

@Serializable
/** 登录会话契约，包含 access token、refresh token 和组织 id。 */
data class AccountSession(
    val accessToken: String? = null,
    val refreshToken: String? = null,
    val orgId: Int? = null,
    val username: String? = null,
    val isLogin: Boolean = false,
)

@Serializable
/** 当前登录用户资料。 */
data class AccountUser(
    val id: Int? = null,
    val username: String? = null,
    val nickname: String? = null,
    val phone: String? = null,
)

@Serializable
/** 首页主区域目标页面。 */
enum class AIHomeDestination {
    Chat,
    History,
    Settings,
}

@Serializable
/** 首页浮层面板类型。 */
enum class AIHomePanel {
    None,
    History,
}

@Serializable
/** 首页会话状态，用于表达登录态、当前入口和历史选择。 */
data class AIHomeSession(
    val isAuthenticated: Boolean,
    val entryDestination: AIHomeDestination,
    val selectedHistoryId: Int? = null,
    val activePanel: AIHomePanel,
)

@Serializable
/** 首页跨模块命令集合。 */
enum class AIHomeCommand {
    OpenAIHome,
    OpenHistoryPanel,
    CloseHistoryPanel,
    SelectHistoryConversation,
    StartNewConversation,
    OpenSettings,
    LogoutToLogin,
}

@Serializable
/** 设置页展示的账号资料。 */
data class SettingAccountInfo(
    val nickname: String? = null,
    val username: String? = null,
    val phone: String? = null,
)

@Serializable
/** 设置页能力开关。 */
data class SettingCapability(
    val canUpdatePassword: Boolean,
    val canOpenPrivacy: Boolean,
    val canLogout: Boolean,
)

@Serializable
/** 设置页快照。 */
data class SettingSnapshot(
    val accountInfo: SettingAccountInfo,
    val capability: SettingCapability,
    val appVersion: String,
)

@Serializable
/** 历史明细角色类型：问题或回答。 */
enum class HistoryDetailType(val rawValue: String) {
    @SerialName("1")
    Question("1"),

    @SerialName("2")
    Answer("2"),
}

@Serializable
/** 历史内容类型：普通 AI 文本或图表 JSON。 */
enum class HistoryContentType(val rawValue: String) {
    @SerialName("1")
    Ai("1"),

    @SerialName("2")
    Chart("2"),
}

@Serializable
/** 单条历史对话明细。 */
data class HistoryDetail(
    val id: Int? = null,
    val historyId: Int? = null,
    val type: HistoryDetailType? = null,
    val contentType: HistoryContentType? = null,
    val content: String? = null,
    val isLike: String? = null,
    val createTime: String? = null,
    val updateTime: String? = null,
)

@Serializable
/** 一次历史会话记录，detailList 在详情接口中返回。 */
data class HistoryRecord(
    val id: Int? = null,
    val name: String? = null,
    val createId: Int? = null,
    val updateId: Int? = null,
    val createName: String? = null,
    val updateName: String? = null,
    val createTime: String? = null,
    val updateTime: String? = null,
    val detailList: List<HistoryDetail>? = null,
)

@Serializable
/** 历史分页接口返回的页信息。 */
data class RecordPage(
    val currentPage: Int? = null,
    val pageSize: Int? = null,
    val total: Int? = null,
    val pages: Int? = null,
    val cacheKey: String? = null,
    val records: List<HistoryRecord>? = null,
)

@Serializable
/** 推荐问题集合。 */
data class TemplateQuestionSet(
    val questions: List<String> = emptyList(),
)

@Serializable
/** 函数调用参数的结构类型。 */
enum class FunctionArgumentKind {
    Basic,
    TimeRange,
    Warehouse,
    AccountAge,
    PerformanceType,
}

@Serializable
/** 后端支持的分析函数名，也是图表接口路径的一部分。 */
enum class FunctionName(val rawValue: String) {
    @SerialName("queryArGroupByOrg")
    QueryArGroupByOrg("queryArGroupByOrg"),
    @SerialName("queryArGroupByCustomer")
    QueryArGroupByCustomer("queryArGroupByCustomer"),
    @SerialName("querySalesGroupByOrgAndGoodsType")
    QuerySalesGroupByOrgAndGoodsType("querySalesGroupByOrgAndGoodsType"),
    @SerialName("querySalesGroupByMonth")
    QuerySalesGroupByMonth("querySalesGroupByMonth"),
    @SerialName("querySalesGroupByCustomer")
    QuerySalesGroupByCustomer("querySalesGroupByCustomer"),
    @SerialName("queryPurchaseGroupByOrg")
    QueryPurchaseGroupByOrg("queryPurchaseGroupByOrg"),
    @SerialName("queryPurchaseGroupByMonth")
    QueryPurchaseGroupByMonth("queryPurchaseGroupByMonth"),
    @SerialName("queryPurchaseGroupByCustomer")
    QueryPurchaseGroupByCustomer("queryPurchaseGroupByCustomer"),
    @SerialName("queryStockGroupByOrg")
    QueryStockGroupByOrg("queryStockGroupByOrg"),
    @SerialName("queryStockGroupByWarehouse")
    QueryStockGroupByWarehouse("queryStockGroupByWarehouse"),
    @SerialName("queryInventoryGroupByOrg")
    QueryInventoryGroupByOrg("queryInventoryGroupByOrg"),
    @SerialName("queryInventoryGroupByWarehouse")
    QueryInventoryGroupByWarehouse("queryInventoryGroupByWarehouse"),
    @SerialName("queryProcurementGroupByOrg")
    QueryProcurementGroupByOrg("queryProcurementGroupByOrg"),
    @SerialName("queryProcurementGroupByCustomer")
    QueryProcurementGroupByCustomer("queryProcurementGroupByCustomer"),
    @SerialName("queryAccountAgeGroupByOrg")
    QueryAccountAgeGroupByOrg("queryAccountAgeGroupByOrg"),
    @SerialName("queryAccountAgeGroupByCustomer")
    QueryAccountAgeGroupByCustomer("queryAccountAgeGroupByCustomer"),
    @SerialName("queryAccountGroupByAge")
    QueryAccountGroupByAge("queryAccountGroupByAge"),
    @SerialName("queryPerformanceType")
    QueryPerformanceType("queryPerformanceType");

    val argumentKind: FunctionArgumentKind
        get() = when (this) {
            QueryArGroupByOrg -> FunctionArgumentKind.Basic
            QueryArGroupByCustomer -> FunctionArgumentKind.Basic
            QuerySalesGroupByOrgAndGoodsType -> FunctionArgumentKind.TimeRange
            QuerySalesGroupByMonth -> FunctionArgumentKind.TimeRange
            QuerySalesGroupByCustomer -> FunctionArgumentKind.TimeRange
            QueryPurchaseGroupByOrg -> FunctionArgumentKind.TimeRange
            QueryPurchaseGroupByMonth -> FunctionArgumentKind.TimeRange
            QueryPurchaseGroupByCustomer -> FunctionArgumentKind.TimeRange
            QueryStockGroupByOrg -> FunctionArgumentKind.Warehouse
            QueryStockGroupByWarehouse -> FunctionArgumentKind.Warehouse
            QueryInventoryGroupByOrg -> FunctionArgumentKind.Warehouse
            QueryInventoryGroupByWarehouse -> FunctionArgumentKind.Warehouse
            QueryProcurementGroupByOrg -> FunctionArgumentKind.Warehouse
            QueryProcurementGroupByCustomer -> FunctionArgumentKind.Warehouse
            QueryAccountAgeGroupByOrg -> FunctionArgumentKind.AccountAge
            QueryAccountAgeGroupByCustomer -> FunctionArgumentKind.AccountAge
            QueryAccountGroupByAge -> FunctionArgumentKind.Basic
            QueryPerformanceType -> FunctionArgumentKind.PerformanceType
        }

    companion object {
        /** 根据后端原始函数名找到强类型枚举。 */
        fun fromRawValue(rawValue: String): FunctionName? = entries.firstOrNull { it.rawValue == rawValue }
    }
}

@Serializable
/** 基础查询参数。 */
data class BasicQuery(
    val orgId: Int? = null,
    val customerName: String? = null,
    val orderType: String? = null,
    val operator: String? = null,
    val value: Double? = null,
)

@Serializable
/** 带时间范围的查询参数。 */
data class TimeRangeQuery(
    val startDate: String? = null,
    val endDate: String? = null,
    val orgId: Int? = null,
    val customerName: String? = null,
    val goodsType: Int? = null,
    val orderType: String? = null,
    val operator: String? = null,
    val value: Double? = null,
)

@Serializable
/** 仓库维度查询参数。 */
data class WarehouseQuery(
    val orgId: Int? = null,
    val warehouseName: String? = null,
    val goodsType: Int? = null,
    val orderType: String? = null,
    val operator: String? = null,
    val value: Double? = null,
)

@Serializable
/** 账龄查询参数。 */
data class AccountAgeQuery(
    val orgId: Int? = null,
    val customerName: String? = null,
    val orderType: String? = null,
    val valueArray: List<String>? = null,
)

@Serializable
/** 经营指标类型查询参数。 */
data class PerformanceTypeQuery(
    val indexType: String? = null,
)

@Serializable
/** 函数参数联合类型，按 kind 约束具体参数结构。 */
sealed interface FunctionArguments {
    val kind: FunctionArgumentKind

    @Serializable
    data class Basic(val value: BasicQuery) : FunctionArguments {
        override val kind: FunctionArgumentKind = FunctionArgumentKind.Basic
    }

    @Serializable
    data class TimeRange(val value: TimeRangeQuery) : FunctionArguments {
        override val kind: FunctionArgumentKind = FunctionArgumentKind.TimeRange
    }

    @Serializable
    data class Warehouse(val value: WarehouseQuery) : FunctionArguments {
        override val kind: FunctionArgumentKind = FunctionArgumentKind.Warehouse
    }

    @Serializable
    data class AccountAge(val value: AccountAgeQuery) : FunctionArguments {
        override val kind: FunctionArgumentKind = FunctionArgumentKind.AccountAge
    }

    @Serializable
    data class PerformanceType(val value: PerformanceTypeQuery) : FunctionArguments {
        override val kind: FunctionArgumentKind = FunctionArgumentKind.PerformanceType
    }
}

@Serializable
/** 函数识别接口返回模型。 */
data class FunctionModel(
    val historyId: Int? = null,
    val hasTool: Boolean? = null,
    val name: FunctionName? = null,
    val msg: String? = null,
    val arguments: FunctionArguments? = null,
)

@Serializable
/** 通用单值图表数据项。 */
data class ChartCommonItem(
    val bizId: String? = null,
    val name: String? = null,
    val value: Double? = null,
)

@Serializable
/** 账龄分组图表数据项。 */
data class AccountAgeGroupItem(
    val name: String? = null,
    val valueList: List<Double>? = null,
    val labelList: List<String>? = null,
    val msg: String? = null,
    val chartType: String? = null,
)

@Serializable
/** 历史图表详情，兼容普通图表和账龄图表两种结构。 */
data class HistoryChartDetail(
    val historyDetailId: Int? = null,
    val funcType: FunctionName? = null,
    val chartCommonVoList: List<ChartCommonItem>? = null,
    val accountAgeGroupVoList: List<AccountAgeGroupItem>? = null,
)

@Serializable
/** 聊天消息角色。 */
enum class ConversationRole {
    User,
    Assistant,
}

@Serializable
/** 聊天消息展示类型。 */
enum class ConversationContentKind {
    Welcome,
    Text,
    Intent,
    Chart,
}

@Serializable
/** 助手需要用户补充的意图类型。 */
enum class AIChatIntentType {
    Time,
    Index,
}

@Serializable
/** 回答反馈状态。 */
enum class FeedbackState {
    Liked,
    Disliked,
    None,
    Unknown,
}

@Serializable
/** 图表数值单位。 */
enum class ChartUnit {
    Currency,
    Ton,
}

@Serializable
/** 一组可绘制的图表序列。 */
data class ChartSeries(
    val xAxis: String,
    val labels: List<String>,
    val values: List<Double>,
)

@Serializable
/** 图表消息的视图载荷。 */
data class ChartPayload(
    val functionName: FunctionName? = null,
    val unit: ChartUnit,
    val series: List<ChartSeries>,
    val emptyMessage: String? = null,
)

@Serializable
/** 聊天页单条消息契约，兼容文本、意图和图表。 */
data class ConversationMessage(
    val id: String,
    val role: ConversationRole,
    val contentKind: ConversationContentKind,
    val text: String? = null,
    val intentType: AIChatIntentType? = null,
    val chartPayload: ChartPayload? = null,
    val feedback: FeedbackState = FeedbackState.None,
    val historyDetailId: Int? = null,
    val functionName: FunctionName? = null,
)
