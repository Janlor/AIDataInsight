package com.aidatainsight.android.feature.aichat.data

import com.aidatainsight.android.core.account.runtime.AccountRuntime
import com.aidatainsight.android.core.model.contract.FunctionArguments
import com.aidatainsight.android.core.model.contract.FunctionModel
import com.aidatainsight.android.core.model.contract.FunctionName
import com.aidatainsight.android.core.model.contract.HistoryChartDetail
import com.aidatainsight.android.core.model.contract.HistoryRecord
import com.aidatainsight.android.core.model.contract.TemplateQuestionSet
import com.aidatainsight.android.core.network.client.AIDataInsightApiClient
import com.aidatainsight.android.core.network.service.AIChatRemoteService
import com.aidatainsight.android.core.network.service.ChartRemoteService
import com.aidatainsight.android.core.network.service.HistoryRemoteService
import com.aidatainsight.android.core.network.service.KtorAIChatRemoteService
import com.aidatainsight.android.core.network.service.KtorChartRemoteService
import com.aidatainsight.android.core.network.service.KtorHistoryRemoteService
import com.aidatainsight.android.feature.aichat.application.AIChatApplicationMapper
import com.aidatainsight.android.feature.aichat.domain.AIChatRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.json.JsonObject

class DefaultAIChatRepository(
    private val apiClient: AIDataInsightApiClient = AccountRuntime.graph.apiClient,
    private val aiChatRemoteService: AIChatRemoteService = KtorAIChatRemoteService(apiClient),
    private val historyRemoteService: HistoryRemoteService = KtorHistoryRemoteService(apiClient),
    private val chartRemoteService: ChartRemoteService = KtorChartRemoteService(apiClient),
) : AIChatRepository {
    /** 加载欢迎态推荐问题，接口为空时返回空集合。 */
    override suspend fun loadTemplate(): TemplateQuestionSet {
        return aiChatRemoteService.loadChatTemplate() ?: TemplateQuestionSet()
    }

    /** 加载历史详情，供聊天页回放历史会话。 */
    override suspend fun loadHistoryDetail(historyId: Int): HistoryRecord {
        return historyRemoteService.historyDetail(historyId) ?: HistoryRecord(id = historyId)
    }

    /** 调用函数识别接口，并把动态 JSON 转成强类型 FunctionModel。 */
    override suspend fun sendFunctionMessage(text: String, historyId: Int?): FunctionModel {
        val data = apiClient.get<JsonObject>(
            path = "/chat/function",
            query = mapOf(
                "question" to text,
                "historyId" to historyId,
            ),
        )
        return data?.let(AIChatApplicationMapper::makeFunctionModel)
            ?: FunctionModel(msg = "AI 分析响应为空。")
    }

    /** 根据函数识别结果加载图表详情。 */
    override suspend fun loadChartData(
        name: FunctionName,
        historyId: Int,
        arguments: FunctionArguments,
    ): HistoryChartDetail {
        return chartRemoteService.loadChartData(
            functionName = name,
            historyId = historyId,
            arguments = arguments,
        ) ?: HistoryChartDetail(funcType = name)
    }

    /** 提交点赞/点踩反馈。 */
    override suspend fun sendLikeFeedback(historyDetailId: Int, like: String) {
        historyRemoteService.likeHistoryDetail(
            historyDetailId = historyDetailId,
            like = like,
        )
    }

    /** 文本流兜底接口。 */
    override fun streamMessage(text: String): Flow<String> = aiChatRemoteService.streamMessage(text)
}
