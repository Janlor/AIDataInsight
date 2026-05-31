package com.aidatainsight.android.core.model.account

import kotlinx.serialization.Serializable

@Serializable
/** 账号领域用户资料模型。 */
data class AccountUser(
    val id: Int? = null,
    val phone: String? = null,
    val username: String? = null,
    val nickname: String? = null,
)
