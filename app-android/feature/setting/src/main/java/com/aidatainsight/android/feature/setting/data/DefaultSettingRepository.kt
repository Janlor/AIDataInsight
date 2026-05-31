package com.aidatainsight.android.feature.setting.data

import com.aidatainsight.android.core.account.runtime.AccountGraph
import com.aidatainsight.android.core.account.runtime.AccountRuntime
import com.aidatainsight.android.core.model.setting.SettingAccountInfo
import com.aidatainsight.android.core.model.setting.SettingCapability
import com.aidatainsight.android.core.model.setting.SettingSnapshot
import com.aidatainsight.android.feature.setting.domain.SettingRepository

class DefaultSettingRepository(
    private val accountGraph: AccountGraph = AccountRuntime.graph,
) : SettingRepository {
    /** 从本地会话和用户缓存构建设置页快照。 */
    override suspend fun loadCachedSnapshot(): SettingSnapshot {
        val cachedUser = accountGraph.userStore.getUser()
        val session = accountGraph.sessionStore.currentSession()

        return SettingSnapshot(
            accountInfo = SettingAccountInfo(
                nickname = cachedUser?.nickname,
                username = cachedUser?.username ?: session?.username,
                phone = cachedUser?.phone,
            ),
            capability = SettingCapability(
                canUpdatePassword = true,
                canOpenPrivacy = true,
                canLogout = true,
            ),
            appVersion = "0.1.0 (1)",
        )
    }

    /** 刷新远端用户资料，并映射为设置页快照。 */
    override suspend fun refreshRemoteSnapshot(): Result<SettingSnapshot> {
        return accountGraph.accountRemoteService.getUserInfo()
            .map { remoteUser ->
                val session = accountGraph.sessionStore.currentSession()
                SettingSnapshot(
                    accountInfo = SettingAccountInfo(
                        nickname = remoteUser.nickname,
                        username = remoteUser.username ?: session?.username,
                        phone = remoteUser.phone,
                    ),
                    capability = SettingCapability(
                        canUpdatePassword = true,
                        canOpenPrivacy = true,
                        canLogout = true,
                    ),
                    appVersion = "0.1.0 (1)",
                )
            }
    }

    /** 退出登录并清理账号缓存。 */
    override suspend fun logout(): Result<Unit> {
        return accountGraph.authService.logout()
    }
}
