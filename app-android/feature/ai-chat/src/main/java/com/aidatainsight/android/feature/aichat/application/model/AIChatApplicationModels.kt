package com.aidatainsight.android.feature.aichat.application.model

import com.aidatainsight.android.core.model.contract.AIChatIntentType
import com.aidatainsight.android.core.model.contract.ChartPayload
import com.aidatainsight.android.core.model.contract.ConversationMessage
import com.aidatainsight.android.core.model.contract.FunctionArguments
import com.aidatainsight.android.core.model.contract.FunctionName

/** Use case 统一结果，避免 ViewModel 直接处理异常类型。 */
sealed interface UseCaseResult<out T> {
    data class Success<T>(val value: T) : UseCaseResult<T>
    data class Failure(val message: String?) : UseCaseResult<Nothing>
}

/** 推荐问题加载结果。 */
data class LoadTemplateOutput(
    val questions: List<String>,
)

/** 历史详情加载结果。 */
data class LoadHistoryDetailOutput(
    val messages: List<ConversationMessage>,
)

/** 函数识别后的下一步动作：补参数或请求图表。 */
sealed interface SendFunctionMessageOutput {
    data class Intent(
        val text: String,
        val type: AIChatIntentType,
    ) : SendFunctionMessageOutput

    data class ChartRequest(
        val name: FunctionName,
        val historyId: Int,
        val arguments: FunctionArguments,
    ) : SendFunctionMessageOutput
}

/** 图表数据加载结果。 */
data class LoadChartDataOutput(
    val payload: ChartPayload,
)
