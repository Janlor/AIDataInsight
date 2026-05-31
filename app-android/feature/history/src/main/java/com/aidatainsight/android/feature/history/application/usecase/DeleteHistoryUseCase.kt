package com.aidatainsight.android.feature.history.application.usecase

import com.aidatainsight.android.feature.history.application.model.DeleteHistoryOutput
import com.aidatainsight.android.feature.history.application.model.HistoryRecordGroup
import com.aidatainsight.android.feature.history.application.model.HistoryStateSnapshot
import com.aidatainsight.android.feature.history.domain.HistoryRepository

class DeleteHistoryUseCase(
    private val repository: HistoryRepository,
) {
    /** 删除远端记录后，从已有分组中移除对应项。 */
    suspend operator fun invoke(
        historyId: Int,
        existingGroups: List<HistoryRecordGroup>,
    ): DeleteHistoryOutput {
        repository.deleteHistory(historyId)
        val groups = existingGroups.mapNotNull { group ->
            // 删除后如果分组为空，也一并移除该分区。
            val records = group.records.filter { it.id != historyId }
            if (records.isEmpty()) null else group.copy(records = records)
        }
        return DeleteHistoryOutput(
            deletedHistoryId = historyId,
            state = HistoryStateSnapshot(page = null, groups = groups),
        )
    }
}
