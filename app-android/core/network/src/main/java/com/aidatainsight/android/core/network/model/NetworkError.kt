package com.aidatainsight.android.core.network.model

class NetworkException(
    /** 后端业务码或 HTTP 状态码。 */
    val errorCode: Int? = null,
    override val message: String,
    cause: Throwable? = null,
) : Exception(message, cause)
