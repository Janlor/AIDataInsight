package com.aidatainsight.android.feature.aichat.application.usecase

import com.aidatainsight.android.feature.aichat.domain.AIChatRepository

class SendLikeFeedbackUseCase(
    private val repository: AIChatRepository,
) {
    /** 提交单条历史回答的反馈状态。 */
    suspend operator fun invoke(historyDetailId: Int, like: String): Result<Unit> {
        return runCatching {
            repository.sendLikeFeedback(historyDetailId = historyDetailId, like = like)
        }
    }
}
