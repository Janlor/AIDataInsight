package com.aidatainsight.android.feature.history.data

import com.aidatainsight.android.core.account.runtime.AccountRuntime
import com.aidatainsight.android.core.model.contract.RecordPage
import com.aidatainsight.android.core.network.client.AIDataInsightApiClient
import com.aidatainsight.android.core.network.service.HistoryRemoteService
import com.aidatainsight.android.core.network.service.KtorHistoryRemoteService
import com.aidatainsight.android.feature.history.domain.HistoryRepository

class DefaultHistoryRepository(
    private val apiClient: AIDataInsightApiClient = AccountRuntime.graph.apiClient,
    private val remoteService: HistoryRemoteService = KtorHistoryRemoteService(apiClient),
) : HistoryRepository {
    /** 加载历史分页，接口为空时返回空记录页。 */
    override suspend fun loadHistoryPage(currentPage: Int, pageSize: Int): RecordPage {
        return remoteService.pageHistory(currentPage = currentPage, pageSize = pageSize)
            ?: RecordPage(currentPage = currentPage, pageSize = pageSize, records = emptyList())
    }

    /** 软删除单条历史记录。 */
    override suspend fun deleteHistory(historyId: Int) {
        remoteService.deleteHistory(historyId)
    }

    /** 软删除当前用户全部历史记录。 */
    override suspend fun deleteAllHistory() {
        remoteService.deleteAllHistory()
    }
}
