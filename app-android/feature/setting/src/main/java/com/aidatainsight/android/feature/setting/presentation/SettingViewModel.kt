package com.aidatainsight.android.feature.setting.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aidatainsight.android.feature.setting.data.DefaultSettingRepository
import com.aidatainsight.android.feature.setting.domain.SettingRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class SettingViewModel(
    private val repository: SettingRepository = DefaultSettingRepository(),
) : ViewModel() {
    private val _uiState = MutableStateFlow(SettingUiState())
    val uiState: StateFlow<SettingUiState> = _uiState.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            runCatching { repository.loadCachedSnapshot() }
                .onSuccess { snapshot ->
                    // 先展示本地缓存资料，再异步刷新远端资料，减少设置页空白时间。
                    _uiState.value = _uiState.value.copy(
                        snapshot = snapshot,
                        isLoading = false,
                    )
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = error.message ?: "加载失败",
                    )
                }
            repository.refreshRemoteSnapshot()
                .onSuccess { snapshot ->
                    _uiState.value = _uiState.value.copy(snapshot = snapshot)
                }
        }
    }

    fun logout(onSuccess: () -> Unit) {
        if (_uiState.value.isLoggingOut) return

        viewModelScope.launch {
            // 退出成功后会清理账号模块缓存，页面导航交给调用方处理。
            _uiState.value = _uiState.value.copy(isLoggingOut = true, errorMessage = null)
            repository.logout()
                .onSuccess {
                    _uiState.value = _uiState.value.copy(isLoggingOut = false)
                    onSuccess()
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(
                        isLoggingOut = false,
                        errorMessage = error.message ?: "退出登录失败",
                    )
                }
        }
    }

    fun dismissError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }
}
