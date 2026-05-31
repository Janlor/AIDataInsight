package com.aidatainsight.android.core.network.client

import com.aidatainsight.android.core.network.auth.NetworkCredentialProvider
import com.aidatainsight.android.core.network.auth.NetworkDependencies
import com.aidatainsight.android.core.network.auth.SessionInvalidationHandler
import com.aidatainsight.android.core.network.auth.TokenRefreshCoordinator
import com.aidatainsight.android.core.network.model.ApiResponse
import com.aidatainsight.android.core.network.model.NetworkException
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.bearerAuth
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.request.post
import io.ktor.client.request.prepareGet
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsChannel
import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.utils.io.readUTF8Line
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.JsonElement

class AIDataInsightApiClient(
    private val config: NetworkConfig,
    private val httpClient: HttpClient = AIDataInsightHttpClientFactory.create(),
    @PublishedApi internal val credentialProvider: NetworkCredentialProvider = NetworkDependencies.credentialProvider,
    @PublishedApi internal val tokenRefreshCoordinator: TokenRefreshCoordinator = NetworkDependencies.tokenRefreshCoordinator,
    @PublishedApi internal val sessionInvalidationHandler: SessionInvalidationHandler = NetworkDependencies.sessionInvalidationHandler,
) {
    /** 发起 GET 请求并解出统一响应信封中的 data。 */
    suspend inline fun <reified T> get(
        path: String,
        query: Map<String, Any?> = emptyMap(),
    ): T? = request(path = path, query = query, body = null, method = Method.Get, hasRetriedAfterRefresh = false)

    /** 发起 POST 请求并解出统一响应信封中的 data。 */
    suspend inline fun <reified T> post(
        path: String,
        body: Any? = null,
        query: Map<String, Any?> = emptyMap(),
    ): T? = request(path = path, query = query, body = body, method = Method.Post, hasRetriedAfterRefresh = false)

    /** 服务端无业务返回值的 GET 请求。 */
    suspend fun getEmpty(
        path: String,
        query: Map<String, Any?> = emptyMap(),
    ) {
        request<JsonElement>(path = path, query = query, body = null, method = Method.Get, hasRetriedAfterRefresh = false)
    }

    /** 服务端无业务返回值的 POST 请求。 */
    suspend fun postEmpty(
        path: String,
        body: Any? = null,
        query: Map<String, Any?> = emptyMap(),
    ) {
        request<JsonElement>(path = path, query = query, body = body, method = Method.Post, hasRetriedAfterRefresh = false)
    }

    /** 读取 Server-Sent Events 文本流，逐条发出 data 行内容。 */
    fun streamServerSentEvents(
        path: String,
        query: Map<String, Any?> = emptyMap(),
    ): Flow<String> = flow {
        httpClient.prepareGet(requestUrl(path)) {
            applyCommonHeaders()
            applyQuery(query)
            header("Accept", "text/event-stream")
            header("Cache-Control", "no-cache")
        }.execute { response ->
            if (response.status !in HttpStatusCode.OK..HttpStatusCode.MultipleChoices) {
                throw NetworkException(errorCode = response.status.value, message = "HTTP ${response.status.value}")
            }

            val channel = response.bodyAsChannel()
            while (!channel.isClosedForRead) {
                val line = channel.readUTF8Line() ?: break
                val chunk = parseServerSentEventLine(line) ?: continue
                if (chunk == "[DONE]") break
                emit(chunk)
            }
        }
    }

    suspend inline fun <reified T> request(
        path: String,
        query: Map<String, Any?>,
        body: Any?,
        method: Method,
        hasRetriedAfterRefresh: Boolean,
    ): T? {
        var hasRetried = hasRetriedAfterRefresh

        while (true) {
            val response = execute(path = path, query = query, body = body, method = method)
            if (response.status !in HttpStatusCode.OK..HttpStatusCode.MultipleChoices) {
                throw NetworkException(errorCode = response.status.value, message = "HTTP ${response.status.value}")
            }

            val envelope = try {
                response.body<ApiResponse<T>>()
            } catch (error: SerializationException) {
                throw NetworkException(message = "响应解析失败。", cause = error)
            }

            when (envelope.code) {
                null, 200 -> return envelope.data
                401, 600 -> {
                    // 401/600 约定为会话不可恢复，直接清理登录态并交给上层回登录页。
                    sessionInvalidationHandler.invalidateSession(envelope.msg)
                    throw NetworkException(errorCode = envelope.code, message = envelope.msg ?: "登录状态已失效。")
                }
                402 -> {
                    if (hasRetried) {
                        sessionInvalidationHandler.invalidateSession(envelope.msg)
                        throw NetworkException(errorCode = 402, message = envelope.msg ?: "登录状态已过期。")
                    }

                    // 402 表示 access token 过期；刷新成功后只重试一次原请求。
                    val refreshed = tokenRefreshCoordinator.refreshIfNeeded(credentialProvider.refreshToken)
                    if (!refreshed) {
                        sessionInvalidationHandler.invalidateSession(envelope.msg)
                        throw NetworkException(errorCode = 402, message = envelope.msg ?: "登录状态已过期。")
                    }
                    hasRetried = true
                }
                else -> throw NetworkException(errorCode = envelope.code, message = envelope.msg ?: "请求失败。")
            }
        }
    }

    suspend fun execute(
        path: String,
        query: Map<String, Any?>,
        body: Any?,
        method: Method,
    ): HttpResponse {
        // execute 只负责发出 HTTP 请求，响应信封和 token 刷新在 request 中统一处理。
        val url = requestUrl(path)
        return when (method) {
            Method.Get -> httpClient.get(url) {
                applyCommonHeaders()
                applyQuery(query)
            }
            Method.Post -> httpClient.post(url) {
                applyCommonHeaders()
                applyQuery(query)
                contentType(ContentType.Application.Json)
                if (body != null) setBody(body)
            }
        }
    }

    private fun requestUrl(path: String): String = config.baseUrl.trimEnd('/') + "/" + path.trimStart('/')

    private fun HttpRequestBuilder.applyCommonHeaders() {
        // 认证头和组织 id 由账号模块提供，网络层不直接读取本地存储。
        credentialProvider.accessToken?.takeIf { it.isNotBlank() }?.let { bearerAuth(it) }
        credentialProvider.orgId?.let { header("Org-Id", it.toString()) }
    }

    private fun HttpRequestBuilder.applyQuery(query: Map<String, Any?>) {
        query.forEach { (key, value) ->
            when (value) {
                null -> Unit
                is Iterable<*> -> value.forEach { item -> parameter(key, item) }
                else -> parameter(key, value)
            }
        }
    }

    enum class Method {
        Get,
        Post,
    }
}

private fun parseServerSentEventLine(line: String): String? {
    // SSE 中只有 data 行是业务文本，其余控制行在当前客户端里忽略。
    val trimmed = line.trim()
    return when {
        trimmed.isBlank() -> null
        trimmed.startsWith(":") -> null
        trimmed.startsWith("event:") -> null
        trimmed.startsWith("id:") -> null
        trimmed.startsWith("retry:") -> null
        trimmed.startsWith("data:") -> trimmed.removePrefix("data:").trim()
        else -> trimmed
    }
}
