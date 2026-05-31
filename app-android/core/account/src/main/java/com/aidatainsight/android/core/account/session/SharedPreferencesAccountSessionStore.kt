package com.aidatainsight.android.core.account.session

import android.content.Context
import android.content.SharedPreferences
import com.aidatainsight.android.core.model.account.AccountSession

/** SharedPreferences 会话存储，用于保存 token、组织 id 和用户名。 */
class SharedPreferencesAccountSessionStore(
    context: Context,
) : AccountSessionStore {
    private val preferences: SharedPreferences = context.applicationContext.getSharedPreferences(
        SESSION_PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )

    override val isLogin: Boolean
        get() = accessToken.isNullOrBlank().not()

    override val accessToken: String?
        get() = preferences.getString(KEY_ACCESS_TOKEN, null)

    override val refreshToken: String?
        get() = preferences.getString(KEY_REFRESH_TOKEN, null)

    override val orgId: Int?
        get() = if (preferences.contains(KEY_ORG_ID)) preferences.getInt(KEY_ORG_ID, 0) else null

    override val username: String?
        get() = preferences.getString(KEY_USERNAME, null)

    override suspend fun update(session: AccountSession) {
        updateImmediately(session)
    }

    override suspend fun remove() {
        removeImmediately()
    }

    override suspend fun currentSession(): AccountSession? {
        return currentSessionImmediately()
    }

    fun updateImmediately(session: AccountSession) {
        preferences.edit()
            .putNullableString(KEY_ACCESS_TOKEN, session.accessToken)
            .putNullableString(KEY_REFRESH_TOKEN, session.refreshToken)
            .putNullableInt(KEY_ORG_ID, session.orgId)
            .putNullableString(KEY_USERNAME, session.username)
            .apply()
    }

    fun removeImmediately() {
        preferences.edit().clear().apply()
    }

    fun currentSessionImmediately(): AccountSession? {
        // access token 为空但 refresh token 还在时，仍返回会话用于尝试刷新。
        if (!isLogin && refreshToken.isNullOrBlank()) return null
        return AccountSession(
            accessToken = accessToken,
            refreshToken = refreshToken,
            orgId = orgId,
            username = username,
        )
    }

    private fun SharedPreferences.Editor.putNullableString(
        key: String,
        value: String?,
    ): SharedPreferences.Editor {
        return if (value == null) remove(key) else putString(key, value)
    }

    private fun SharedPreferences.Editor.putNullableInt(
        key: String,
        value: Int?,
    ): SharedPreferences.Editor {
        return if (value == null) remove(key) else putInt(key, value)
    }

    private companion object {
        const val SESSION_PREFERENCES_NAME = "ai_data_insight_account_session"
        const val KEY_ACCESS_TOKEN = "access_token"
        const val KEY_REFRESH_TOKEN = "refresh_token"
        const val KEY_ORG_ID = "org_id"
        const val KEY_USERNAME = "username"
    }
}
