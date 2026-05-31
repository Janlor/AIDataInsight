package com.aidatainsight.android.core.account.auth

import com.aidatainsight.android.core.model.account.AccountSession
import com.aidatainsight.android.core.model.account.AccountUser
import com.aidatainsight.android.core.network.model.OAuthModel

internal fun OAuthModel.toAccountSession(
    username: String? = null,
    previous: AccountSession? = null,
): AccountSession {
    // 刷新 token 时后端可能只返回部分字段，因此保留 previous 中仍有效的值。
    return AccountSession(
        accessToken = accessToken ?: previous?.accessToken,
        refreshToken = refreshToken ?: previous?.refreshToken,
        orgId = orgId ?: previous?.orgId,
        username = username ?: this.username ?: previous?.username,
    )
}

internal fun com.aidatainsight.android.core.model.contract.AccountUser.toAccountUser(): AccountUser {
    // contract 层模型与 account 领域模型隔离，避免网络字段直接扩散到业务层。
    return AccountUser(
        id = id,
        phone = phone,
        username = username,
        nickname = nickname,
    )
}
