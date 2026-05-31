package com.aidatainsight.android.feature.privacy.presentation

import androidx.lifecycle.ViewModel
import com.aidatainsight.android.feature.privacy.data.DefaultPrivacyRepository
import com.aidatainsight.android.feature.privacy.domain.PrivacyRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class PrivacyPolicyViewModel(
    private val repository: PrivacyRepository = DefaultPrivacyRepository(),
) : ViewModel() {
    private var hasShownPolicy = false
    private val _uiState = MutableStateFlow(PrivacyDialogState())
    val uiState: StateFlow<PrivacyDialogState> = _uiState.asStateFlow()

    fun evaluate() {
        // 单次进程内只自动弹一次，避免用户返回登录页时被重复打断。
        if (!hasShownPolicy && !repository.isAgreedAllPolicyAgreement()) {
            hasShownPolicy = true
            _uiState.value = PrivacyDialogState(
                shouldShow = true,
                privacyPolicyUrl = repository.privacyPolicyUrl(),
            )
        }
    }

    fun privacyPolicyUrl(): String = repository.privacyPolicyUrl()
}
