package com.aidatainsight.android.feature.history.application.usecase

import com.aidatainsight.android.feature.history.application.HistoryApplicationMapper
import com.aidatainsight.android.feature.history.application.model.HistoryRecordGroup
import com.aidatainsight.android.feature.history.application.model.HistoryStateSnapshot
import com.aidatainsight.android.feature.history.domain.HistoryRepository

class LoadHistoryPageUseCase(
    private val repository: HistoryRepository,
) {
    /** 加载历史分页，并与现有分组合并。 */
    suspend operator fun invoke(
        currentPage: Int,
        pageSize: Int,
        existingGroups: List<HistoryRecordGroup>,
    ): HistoryStateSnapshot {
        val page = repository.loadHistoryPage(currentPage = currentPage, pageSize = pageSize)
        val newGroups = HistoryApplicationMapper.groupRecords(page.records)
        val groups = if ((page.currentPage ?: currentPage) == 1 || existingGroups.isEmpty()) {
            // 第一页代表刷新，直接替换已有列表。
            newGroups
        } else {
            HistoryApplicationMapper.mergeGroups(existingGroups, newGroups)
        }
        return HistoryStateSnapshot(page = page, groups = groups)
    }
}
