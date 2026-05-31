package com.aidatainsight.android.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.Button
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.aidatainsight.android.core.ui.theme.AIDataInsightThemeTokens
import com.aidatainsight.android.feature.aichat.presentation.AIChatViewModel
import com.aidatainsight.android.feature.aichat.ui.AIChatBackground
import com.aidatainsight.android.feature.aichat.ui.AIChatScreen
import com.aidatainsight.android.feature.history.presentation.HistoryViewModel
import com.aidatainsight.android.feature.history.ui.HistoryScreen
import kotlinx.coroutines.launch

@Composable
fun AIHomeScreen(
    onOpenSettings: () -> Unit,
    chatViewModel: AIChatViewModel = viewModel(),
    historyViewModel: HistoryViewModel = viewModel(),
) {
    AIChatBackground(modifier = Modifier.fillMaxSize()) {
        BoxWithConstraints(
            modifier = Modifier.fillMaxSize(),
        ) {
            // 600dp 以上使用左右分栏，紧凑设备使用抽屉承载历史列表。
            val isRegular = maxWidth >= 600.dp
            if (isRegular) {
                RegularAIHome(
                    onOpenSettings = onOpenSettings,
                    chatViewModel = chatViewModel,
                    historyViewModel = historyViewModel,
                )
            } else {
                CompactAIHome(
                    onOpenSettings = onOpenSettings,
                    chatViewModel = chatViewModel,
                    historyViewModel = historyViewModel,
                )
            }
        }
    }
}

@Composable
private fun CompactAIHome(
    onOpenSettings: () -> Unit,
    chatViewModel: AIChatViewModel,
    historyViewModel: HistoryViewModel,
) {
    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()

    LaunchedEffect(drawerState.isOpen) {
        if (drawerState.isOpen) {
            // 打开历史抽屉时静默刷新，让新会话尽快出现在列表里。
            historyViewModel.refresh(silent = true)
        }
    }

    ModalNavigationDrawer(
        modifier = Modifier.fillMaxSize(),
        drawerState = drawerState,
        gesturesEnabled = true,
        drawerContent = {
            ModalDrawerSheet(
                modifier = Modifier
                    .fillMaxHeight()
                    .widthIn(max = 360.dp),
                drawerContainerColor = AIDataInsightThemeTokens.colors.groupedBackground.primary,
                windowInsets = WindowInsets(0.dp),
            ) {
                HistoryPanel(
                    onOpenSettings = onOpenSettings,
                    onOpenHistory = { id ->
                        id.toIntOrNull()?.let(chatViewModel::loadConversation)
                        scope.launch { drawerState.close() }
                    },
                    historyViewModel = historyViewModel,
                )
            }
        },
    ) {
        AIHomeChatSurface(
            modifier = Modifier
                .fillMaxSize()
                .safeDrawingPadding()
                .imePadding(),
            onOpenHistory = { scope.launch { drawerState.open() } },
            onStartNewConversation = chatViewModel::startNewConversation,
            chatViewModel = chatViewModel,
        )
    }
}

@Composable
private fun RegularAIHome(
    onOpenSettings: () -> Unit,
    chatViewModel: AIChatViewModel,
    historyViewModel: HistoryViewModel,
) {
    var isHistoryOpen by remember { mutableStateOf(false) }

    LaunchedEffect(isHistoryOpen) {
        if (isHistoryOpen) {
            // 宽屏侧栏展开时刷新历史，保持和紧凑抽屉行为一致。
            historyViewModel.refresh(silent = true)
        }
    }

    Row(
        modifier = Modifier
            .fillMaxSize()
            .safeDrawingPadding()
            .imePadding(),
        horizontalArrangement = Arrangement.Center,
    ) {
        if (isHistoryOpen) {
            Surface(
                modifier = Modifier
                    .width(320.dp)
                    .fillMaxHeight(),
                color = AIDataInsightThemeTokens.colors.groupedBackground.primary,
                shadowElevation = 6.dp,
            ) {
                HistoryPanel(
                    onOpenSettings = onOpenSettings,
                    onOpenHistory = { id ->
                        // 历史列表 id 来自 UI 模型字符串，加载前先转回后端 historyId。
                        id.toIntOrNull()?.let(chatViewModel::loadConversation)
                        isHistoryOpen = false
                    },
                    historyViewModel = historyViewModel,
                )
            }
        }

        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight(),
            contentAlignment = Alignment.TopCenter,
        ) {
            AIHomeChatSurface(
                modifier = Modifier.widthIn(max = 860.dp),
                onOpenHistory = { isHistoryOpen = !isHistoryOpen },
                onStartNewConversation = chatViewModel::startNewConversation,
                chatViewModel = chatViewModel,
            )
        }
    }
}

@Composable
private fun AIHomeChatSurface(
    onOpenHistory: () -> Unit,
    onStartNewConversation: () -> Unit,
    chatViewModel: AIChatViewModel,
    modifier: Modifier = Modifier,
) {
    val colors = AIDataInsightThemeTokens.colors
    // 首页外层负责标题和操作栏，AIChatScreen 只渲染聊天主体。
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OutlinedButton(onClick = onOpenHistory) {
                Text("历史")
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = "AI数据分析助手",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = "经营数据分析",
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.label.secondary,
                )
            }

            Button(onClick = onStartNewConversation) {
                Text("新会话")
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        AIChatScreen(
            modifier = Modifier.weight(1f),
            showHeader = false,
            drawBackground = false,
            viewModel = chatViewModel,
        )
    }
}

@Composable
private fun HistoryPanel(
    onOpenSettings: () -> Unit,
    onOpenHistory: (String) -> Unit,
    historyViewModel: HistoryViewModel,
) {
    HistoryScreen(
        drawBackground = true,
        respectSafeDrawingArea = true,
        onOpenHistory = onOpenHistory,
        onOpenSettings = onOpenSettings,
        viewModel = historyViewModel,
    )
}
