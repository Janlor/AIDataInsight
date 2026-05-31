package com.aidatainsight.android.core.account.runtime

import com.aidatainsight.android.core.account.auth.AccountAuthService
import com.aidatainsight.android.core.account.session.AccountSessionStore
import com.aidatainsight.android.core.account.user.AccountRemoteService
import com.aidatainsight.android.core.account.user.AccountUserStore
import com.aidatainsight.android.core.network.client.AIDataInsightApiClient

/** 账号模块运行时依赖集合，避免在各 Feature 中重复手动构造服务。 */
data class AccountGraph(
    val apiClient: AIDataInsightApiClient,
    val sessionStore: AccountSessionStore,
    val userStore: AccountUserStore,
    val authService: AccountAuthService,
    val accountRemoteService: AccountRemoteService,
)
