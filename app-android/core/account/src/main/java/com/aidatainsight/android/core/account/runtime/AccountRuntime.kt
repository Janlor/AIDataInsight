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

    val graph: AccountGraph
        get() = checkNotNull(installedGraph) { "AccountRuntime has not been installed." }

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

    private const val DEFAULT_BASE_URL = "http://10.0.2.2:3000"
}
