package com.aidatainsight.android.feature.login.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aidatainsight.android.feature.login.data.DefaultLoginRepository
import com.aidatainsight.android.feature.login.domain.LoginRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class LoginViewModel(
    private val repository: LoginRepository = DefaultLoginRepository(),
) : ViewModel() {
    private val _uiState = MutableStateFlow(LoginUiState())
    val uiState: StateFlow<LoginUiState> = _uiState.asStateFlow()

    fun updateUsername(value: String) {
        _uiState.value = _uiState.value.copy(username = value.take(MAX_USERNAME_LENGTH))
    }

    fun updatePassword(value: String) {
        _uiState.value = _uiState.value.copy(password = value.take(MAX_PASSWORD_LENGTH))
    }

    fun togglePrivacyAccepted() {
        _uiState.value = _uiState.value.copy(
            isPrivacyAccepted = !_uiState.value.isPrivacyAccepted,
            errorMessage = null,
        )
    }

    fun login(onSuccess: () -> Unit) {
        if (_uiState.value.isLoading) return
        if (_uiState.value.username.isBlank() || _uiState.value.password.isBlank()) return
        if (!_uiState.value.isPrivacyAccepted) {
            // 隐私协议未确认时不发起登录请求，和 iOS/Web 的入口约束保持一致。
            _uiState.value = _uiState.value.copy(errorMessage = "请先阅读并同意《隐私政策》")
            return
        }

        viewModelScope.launch {
            // 登录成功后由仓库保存会话，导航回调只负责切换页面。
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            repository.login(_uiState.value.username, _uiState.value.password)
                .onSuccess {
                    _uiState.value = _uiState.value.copy(isLoading = false)
                    onSuccess()
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = error.message,
                    )
                }
        }
    }

    companion object {
        const val MAX_USERNAME_LENGTH = 30
        const val MAX_PASSWORD_LENGTH = 30
    }
}
