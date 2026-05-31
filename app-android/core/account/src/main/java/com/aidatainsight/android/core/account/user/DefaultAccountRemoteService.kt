package com.aidatainsight.android.core.account.user

import com.aidatainsight.android.core.account.auth.toAccountUser
import com.aidatainsight.android.core.model.account.AccountUser

class DefaultAccountRemoteService(
    private val networkRemoteService: com.aidatainsight.android.core.network.service.AccountRemoteService,
    private val userStore: AccountUserStore,
) : AccountRemoteService {
    /** 从远端获取用户资料，并写入本地缓存。 */
    override suspend fun getUserInfo(): Result<AccountUser> {
        return runCatching {
            val user = networkRemoteService.getUserInfo()?.toAccountUser()
                ?: error("用户信息响应为空。")
            userStore.updateUser(user)
            user
        }
    }
}
