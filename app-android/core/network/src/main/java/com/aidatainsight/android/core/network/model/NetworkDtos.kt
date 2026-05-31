package com.aidatainsight.android.core.network.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.JsonNames

@Serializable
/** 登录请求体，字段名与后端 /oauth2/login 契约一致。 */
data class LoginRequest(
    val name: String,
    val pwd: String,
)

@Serializable
@OptIn(ExperimentalSerializationApi::class)
/** 登录/刷新接口返回的 token 模型，同时兼容蛇形和驼峰字段。 */
data class OAuthModel(
    @JsonNames("access_token")
    val accessToken: String? = null,
    @JsonNames("refresh_token")
    val refreshToken: String? = null,
    @JsonNames("org_id")
    val orgId: Int? = null,
    val username: String? = null,
)

@Serializable
/** 修改密码请求体。 */
data class UpdatePasswordRequest(
    val oldPwd: String,
    val newPwd: String,
)

@Serializable
/** 历史明细点赞/点踩请求体。 */
data class LikeHistoryDetailRequest(
    val historyDetailId: Int,
    val like: String,
)

@Serializable
/** 菜单树节点，当前主要用于保留后端契约兼容。 */
data class MenuItem(
    val id: Int? = null,
    val name: String? = null,
    val path: String? = null,
    val children: List<MenuItem>? = null,
)
