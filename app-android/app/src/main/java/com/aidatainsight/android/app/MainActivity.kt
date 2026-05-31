package com.aidatainsight.android.app

import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.aidatainsight.android.app.navigation.AppNavHost
import com.aidatainsight.android.core.ui.theme.AIDataInsightTheme

/** 单 Activity Compose 宿主。 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.light(
                scrim = android.graphics.Color.TRANSPARENT,
                darkScrim = android.graphics.Color.TRANSPARENT,
            ),
            navigationBarStyle = SystemBarStyle.light(
                scrim = android.graphics.Color.TRANSPARENT,
                darkScrim = android.graphics.Color.TRANSPARENT,
            ),
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // 关闭系统栏强制对比色，让设计系统背景自然延伸到边缘区域。
            window.isNavigationBarContrastEnforced = false
            window.isStatusBarContrastEnforced = false
        }
        super.onCreate(savedInstanceState)
        setContent {
            AIDataInsightTheme {
                AppNavHost()
            }
        }
    }
}
