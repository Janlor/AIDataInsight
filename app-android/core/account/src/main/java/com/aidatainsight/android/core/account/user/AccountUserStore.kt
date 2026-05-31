package com.aidatainsight.android.core.account.user

import com.aidatainsight.android.core.model.account.AccountUser

/** 当前用户资料缓存抽象。 */
interface AccountUserStore {
    suspend fun updateUser(user: AccountUser)
    suspend fun getUser(): AccountUser?
    suspend fun remove()
}
