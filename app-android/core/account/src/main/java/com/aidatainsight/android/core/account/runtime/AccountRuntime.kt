package com.aidatainsight.android.core.account.runtime

import android.content.Context
import com.aidatainsight.android.core.account.auth.AccountAuthService
import com.aidatainsight.android.core.account.auth.AccountNetworkCredentialProvider
import com.aidatainsight.android.core.account.auth.AccountSessionInvalidationHandler
import com.aidatainsight.android.core.account.auth.AccountTokenRefreshService
import com.aidatainsight.android.core.account.session.SharedPreferencesAccountSessionStore
import com.aidatainsight.android.core.account.user.DefaultAccountRemoteService
import com.aidatainsight.android.core.account.user.SharedPreferencesAccountUserStore
import com.aidatainsight.android.core.network.auth.NetworkDependencies
import com.aidatainsight.android.core.network.auth.TokenRefreshCoordinator
import com.aidatainsight.android.core.network.client.AIDataInsightApiClient
import com.aidatainsight.android.core.network.client.NetworkConfig
import com.aidatainsight.android.core.network.service.KtorAccountRemoteService
import com.aidatainsight.android.core.network.service.KtorAuthRemoteService

object AccountRuntime {
    private var installedGraph: AccountGraph? = null

    /** 已安装的账号依赖图，Application 启动时必须先调用 install。 */
    val graph: AccountGraph
        get() = checkNotNull(installedGraph) { "AccountRuntime has not been installed." }

    /** 组装账号、网络和 token 刷新依赖，并注册到 NetworkDependencies。 */
    fun install(
        context: Context,
        baseUrl: String = DEFAULT_BASE_URL,
    ): AccountGraph {
        installedGraph?.let { return it }

        val sessionStore = SharedPreferencesAccountSessionStore(context)
        val userStore = SharedPreferencesAccountUserStore(context)
        val credentialProvider = AccountNetworkCredentialProvider(sessionStore)
        val invalidationHandler = AccountSessionInvalidationHandler(sessionStore, userStore)

        lateinit var authRemoteService: KtorAuthRemoteService
        // tokenRefreshService 需要 authRemoteService，但 apiClient 又要先拿到刷新协调器，因此这里延迟赋值。
        val tokenRefreshService = AccountTokenRefreshService(sessionStore) { authRemoteService }
        val tokenRefreshCoordinator = TokenRefreshCoordinator(tokenRefreshService)

        NetworkDependencies.credentialProvider = credentialProvider
        NetworkDependencies.tokenRefreshService = tokenRefreshService
        NetworkDependencies.tokenRefreshCoordinator = tokenRefreshCoordinator
        NetworkDependencies.sessionInvalidationHandler = invalidationHandler

        val apiClient = AIDataInsightApiClient(
            config = NetworkConfig(baseUrl = baseUrl),
            credentialProvider = credentialProvider,
            tokenRefreshCoordinator = tokenRefreshCoordinator,
            sessionInvalidationHandler = invalidationHandler,
        )
        authRemoteService = KtorAuthRemoteService(apiClient)
        val accountNetworkRemoteService = KtorAccountRemoteService(apiClient)

        val graph = AccountGraph(
            apiClient = apiClient,
            sessionStore = sessionStore,
            userStore = userStore,
            authService = AccountAuthService(authRemoteService, sessionStore, userStore),
            accountRemoteService = DefaultAccountRemoteService(accountNetworkRemoteService, userStore),
        )
        installedGraph = graph
        return graph
    }

    // Android 模拟器访问宿主机 localhost 需要使用 10.0.2.2。
    private const val DEFAULT_BASE_URL = "http://10.0.2.2:3000"
}
