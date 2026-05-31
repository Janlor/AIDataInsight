package com.aidatainsight.android.feature.history.application.model

import com.aidatainsight.android.core.model.contract.HistoryRecord
import com.aidatainsight.android.core.model.contract.RecordPage

/** 历史列表分页和分组后的快照。 */
data class HistoryStateSnapshot(
    val page: RecordPage?,
    val groups: List<HistoryRecordGroup>,
)

/** 删除历史后的本地状态输出。 */
data class DeleteHistoryOutput(
    val deletedHistoryId: Int,
    val state: HistoryStateSnapshot,
)

/** 按时间标题分组的历史记录。 */
data class HistoryRecordGroup(
    val title: String,
    val records: List<HistoryRecord>,
)
