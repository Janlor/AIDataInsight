package com.aidatainsight.android.feature.aichat.application.usecase

import com.aidatainsight.android.feature.aichat.application.AIChatApplicationMapper
import com.aidatainsight.android.feature.aichat.application.model.LoadHistoryDetailOutput
import com.aidatainsight.android.feature.aichat.domain.AIChatRepository

class LoadHistoryDetailUseCase(
    private val repository: AIChatRepository,
) {
    /** 加载历史详情并转换成聊天消息列表。 */
    suspend operator fun invoke(historyId: Int): LoadHistoryDetailOutput {
        val record = repository.loadHistoryDetail(historyId)
        return LoadHistoryDetailOutput(
            messages = AIChatApplicationMapper.makeMessages(record.detailList.orEmpty()),
        )
    }
}
