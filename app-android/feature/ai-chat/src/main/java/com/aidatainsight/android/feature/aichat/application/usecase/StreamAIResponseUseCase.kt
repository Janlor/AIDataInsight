package com.aidatainsight.android.feature.aichat.application.usecase

import com.aidatainsight.android.feature.aichat.domain.AIChatRepository
import kotlinx.coroutines.flow.Flow

class StreamAIResponseUseCase(
    private val repository: AIChatRepository,
) {
    /** 返回 SSE 文本流，作为结构化分析失败时的兜底能力。 */
    operator fun invoke(text: String): Flow<String> = repository.streamMessage(text)
}
