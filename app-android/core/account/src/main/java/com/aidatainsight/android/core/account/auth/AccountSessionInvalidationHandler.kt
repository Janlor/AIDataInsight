package com.aidatainsight.android.core.account.auth

import com.aidatainsight.android.core.account.session.AccountSessionStore
import com.aidatainsight.android.core.account.session.SharedPreferencesAccountSessionStore
import com.aidatainsight.android.core.account.user.AccountUserStore
import com.aidatainsight.android.core.account.user.SharedPreferencesAccountUserStore
import com.aidatainsight.android.core.network.auth.SessionInvalidationHandler

class AccountSessionInvalidationHandler(
    private val sessionStore: AccountSessionStore,
    private val userStore: AccountUserStore,
) : SessionInvalidationHandler {
    /** 最近一次失效原因，方便 UI 或测试断言。 */
    var lastInvalidationMessage: String? = null
        private set

    override fun invalidateSession(message: String?) {
        // 该回调来自网络层，当前实现需要同步清理本地登录态。
        lastInvalidationMessage = message
        (sessionStore as? SharedPreferencesAccountSessionStore)?.removeImmediately()
        (userStore as? SharedPreferencesAccountUserStore)?.removeImmediately()
    }
}
