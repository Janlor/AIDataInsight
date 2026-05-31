package com.aidatainsight.android.core.common.model

/** 应用内部通用结果类型，用于不直接暴露异常的调用链。 */
sealed interface AppResult<out T> {
    data class Success<T>(val value: T) : AppResult<T>
    data class Failure(val error: AppError) : AppResult<Nothing>
}

/** 应用内部通用错误模型。 */
data class AppError(
    val code: String,
    val message: String,
)
