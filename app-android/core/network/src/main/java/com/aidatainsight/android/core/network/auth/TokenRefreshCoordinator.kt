package com.aidatainsight.android.core.network.auth

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class TokenRefreshCoordinator(
    private val tokenRefreshService: TokenRefreshService,
) {
    private val refreshMutex = Mutex()

    /** 合并并发刷新请求，避免多个接口同时收到 402 时重复刷新 token。 */
    suspend fun refreshIfNeeded(token: String?): Boolean {
        val refreshToken = token ?: return false
        return refreshMutex.withLock {
            tokenRefreshService.refreshToken(refreshToken)
        }
    }
}
