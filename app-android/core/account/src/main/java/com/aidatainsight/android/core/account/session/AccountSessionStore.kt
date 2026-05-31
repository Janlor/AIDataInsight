package com.aidatainsight.android.core.account.session

import com.aidatainsight.android.core.model.account.AccountSession

/** 账号会话存储抽象，生产实现使用 SharedPreferences。 */
interface AccountSessionStore {
    val isLogin: Boolean
    val accessToken: String?
    val refreshToken: String?
    val orgId: Int?
    val username: String?

    suspend fun update(session: AccountSession)
    suspend fun remove()
    suspend fun currentSession(): AccountSession?
}
