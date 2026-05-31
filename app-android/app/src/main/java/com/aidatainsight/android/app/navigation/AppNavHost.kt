package com.aidatainsight.android.app.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.aidatainsight.android.app.ui.AIHomeScreen
import com.aidatainsight.android.core.account.runtime.AccountRuntime
import com.aidatainsight.android.feature.aichat.ui.AIChatScreen
import com.aidatainsight.android.feature.history.ui.HistoryScreen
import com.aidatainsight.android.feature.login.ui.LoginScreen
import com.aidatainsight.android.feature.privacy.ui.PrivacyScreen
import com.aidatainsight.android.feature.setting.ui.SettingScreen

@Composable
fun AppNavHost() {
    val navController = rememberNavController()
    val currentBackStackEntry by navController.currentBackStackEntryAsState()
    val startDestination = remember {
        // 启动页根据本地会话判断，避免已登录用户先看到登录页再跳转。
        if (AccountRuntime.graph.sessionStore.isLogin) {
            AppDestination.AIHome.route
        } else {
            AppDestination.Login.route
        }
    }

    BackHandler(
        // 隐私页可能从登录页或设置页进入，统一先回到上一层。
        enabled = currentBackStackEntry?.destination?.route == AppDestination.Privacy.route,
        onBack = { navController.popBackStack() },
    )

    NavHost(
        navController = navController,
        startDestination = startDestination,
    ) {
        composable(AppDestination.Login.route) {
            LoginScreen(
                onLoginSuccess = {
                    navController.navigateToAIHomeAndClearBackStack()
                },
                onOpenPrivacy = {
                    navController.navigate(AppDestination.Privacy.route)
                },
            )
        }
        composable(AppDestination.AIHome.route) {
            AIHomeScreen(
                onOpenSettings = { navController.navigate(AppDestination.Setting.route) },
            )
        }
        composable(AppDestination.Setting.route) {
            SettingScreen(
                onClose = { navController.popBackStack() },
                onOpenPrivacy = { navController.navigate(AppDestination.Privacy.route) },
                onLogout = {
                    navController.navigateToLoginAndClearBackStack()
                },
            )
        }
        composable(AppDestination.Privacy.route) {
            PrivacyScreen(
                onClose = { navController.popBackStack() },
            )
        }
        composable(AppDestination.History.route) {
            HistoryScreen(respectSafeDrawingArea = true)
        }
        composable(AppDestination.AIChat.route) {
            AIChatScreen()
        }
    }
}

private fun NavHostController.navigateToAIHomeAndClearBackStack() {
    // 登录成功后清空登录页返回栈，系统返回键不会回到登录表单。
    navigate(AppDestination.AIHome.route) {
        popUpTo(graph.findStartDestination().id) { inclusive = true }
        launchSingleTop = true
    }
}

private fun NavHostController.navigateToLoginAndClearBackStack() {
    // 退出登录后清空受保护页面返回栈。
    navigate(AppDestination.Login.route) {
        popUpTo(graph.findStartDestination().id) { inclusive = true }
        launchSingleTop = true
    }
}
