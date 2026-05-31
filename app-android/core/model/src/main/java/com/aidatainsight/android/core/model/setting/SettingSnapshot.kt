package com.aidatainsight.android.core.model.setting

/** 设置页账号资料展示模型。 */
data class SettingAccountInfo(
    val nickname: String?,
    val username: String?,
    val phone: String?,
)

/** 设置页能力开关。 */
data class SettingCapability(
    val canUpdatePassword: Boolean,
    val canOpenPrivacy: Boolean,
    val canLogout: Boolean,
)

/** 设置页完整快照。 */
data class SettingSnapshot(
    val accountInfo: SettingAccountInfo,
    val capability: SettingCapability,
    val appVersion: String,
)
