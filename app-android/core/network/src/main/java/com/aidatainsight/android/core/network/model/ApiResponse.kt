package com.aidatainsight.android.core.network.model

import kotlinx.serialization.Serializable

@Serializable
/** 后端统一响应信封，业务数据位于 data，trace/tid 用于链路排查。 */
data class ApiResponse<T>(
    val code: Int? = null,
    val msg: String? = null,
    val data: T? = null,
    val trace: String? = null,
    val tid: String? = null,
)
