package com.aidatainsight.android.app

import android.app.Application
import com.aidatainsight.android.core.account.runtime.AccountRuntime

/** 应用入口，负责安装账号和网络运行时依赖。 */
class AIDataInsightApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // baseUrl 来自 Gradle BuildConfig，便于 debug/release 或本地联调切换环境。
        AccountRuntime.install(
            context = this,
            baseUrl = BuildConfig.AIDATAINSIGHT_BASE_URL,
        )
    }
}
