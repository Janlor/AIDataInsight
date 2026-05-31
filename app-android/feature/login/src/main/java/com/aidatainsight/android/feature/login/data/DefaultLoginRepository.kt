package com.aidatainsight.android.feature.login.data

import com.aidatainsight.android.core.account.auth.AccountAuthService
import com.aidatainsight.android.core.account.runtime.AccountRuntime
import com.aidatainsight.android.core.model.account.AccountSession
import com.aidatainsight.android.feature.login.domain.LoginRepository

class DefaultLoginRepository(
    private val authService: AccountAuthService = AccountRuntime.graph.authService,
) : LoginRepository {
    /** 登录领域仓库目前直接委托账号服务，保留一层用于后续扩展埋点或策略。 */
    override suspend fun login(username: String, password: String): Result<AccountSession> {
        return authService.login(username = username, password = password)
    }
}
