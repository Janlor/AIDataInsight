package com.aidatainsight.android.core.model.account

import kotlinx.serialization.Serializable

@Serializable
/** 账号领域会话模型，供本地存储和网络鉴权复用。 */
data class AccountSession(
    val accessToken: String? = null,
    val refreshToken: String? = null,
    val orgId: Int? = null,
    val username: String? = null,
)
