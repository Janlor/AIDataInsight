package com.aidatainsight.android.core.account.auth

import com.aidatainsight.android.core.account.session.AccountSessionStore
import com.aidatainsight.android.core.network.auth.NetworkCredentialProvider

class AccountNetworkCredentialProvider(
    private val sessionStore: AccountSessionStore,
) : NetworkCredentialProvider {
    /** 网络层只依赖这个只读提供者，不直接知道会话存储实现。 */
    override val accessToken: String?
        get() = sessionStore.accessToken

    override val refreshToken: String?
        get() = sessionStore.refreshToken

    override val orgId: Int?
        get() = sessionStore.orgId
}
