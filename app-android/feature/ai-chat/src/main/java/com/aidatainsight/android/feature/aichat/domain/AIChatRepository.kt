package com.aidatainsight.android.feature.aichat.domain

import com.aidatainsight.android.core.model.contract.FunctionArguments
import com.aidatainsight.android.core.model.contract.FunctionModel
import com.aidatainsight.android.core.model.contract.FunctionName
import com.aidatainsight.android.core.model.contract.HistoryChartDetail
import com.aidatainsight.android.core.model.contract.HistoryRecord
import com.aidatainsight.android.core.model.contract.TemplateQuestionSet
import kotlinx.coroutines.flow.Flow

/** AI 聊天领域仓库，隔离远端接口和展示层状态机。 */
interface AIChatRepository {
    suspend fun loadTemplate(): TemplateQuestionSet
    suspend fun loadHistoryDetail(historyId: Int): HistoryRecord
    suspend fun sendFunctionMessage(text: String, historyId: Int?): FunctionModel
    suspend fun loadChartData(
        name: FunctionName,
        historyId: Int,
        arguments: FunctionArguments,
    ): HistoryChartDetail
    suspend fun sendLikeFeedback(historyDetailId: Int, like: String)
    fun streamMessage(text: String): Flow<String>
}
