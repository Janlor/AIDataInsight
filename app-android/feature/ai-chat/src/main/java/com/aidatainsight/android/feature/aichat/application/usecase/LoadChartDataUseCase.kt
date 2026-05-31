package com.aidatainsight.android.feature.aichat.application.usecase

import com.aidatainsight.android.core.model.contract.FunctionArguments
import com.aidatainsight.android.core.model.contract.FunctionName
import com.aidatainsight.android.feature.aichat.application.AIChatApplicationMapper
import com.aidatainsight.android.feature.aichat.application.model.LoadChartDataOutput
import com.aidatainsight.android.feature.aichat.application.model.UseCaseResult
import com.aidatainsight.android.feature.aichat.domain.AIChatRepository

class LoadChartDataUseCase(
    private val repository: AIChatRepository,
) {
    /** 校验函数参数类型并加载图表数据。 */
    suspend operator fun invoke(
        name: FunctionName,
        historyId: Int,
        arguments: FunctionArguments,
    ): UseCaseResult<LoadChartDataOutput> {
        if (name.argumentKind != arguments.kind) {
            // 函数名和参数类型不一致时不请求图表，避免构造出错误 query。
            return UseCaseResult.Failure("函数参数类型不匹配。")
        }

        val model = repository.loadChartData(
            name = name,
            historyId = historyId,
            arguments = arguments,
        )
        val payload = AIChatApplicationMapper.makeChartPayload(model)
        if (payload == null || payload.series.isEmpty()) {
            return UseCaseResult.Failure(
                payload?.emptyMessage ?: AIChatApplicationMapper.chartFallbackMessage(),
            )
        }
        return UseCaseResult.Success(LoadChartDataOutput(payload = payload))
    }
}
