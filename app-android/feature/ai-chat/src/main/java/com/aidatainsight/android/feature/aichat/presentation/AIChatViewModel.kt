package com.aidatainsight.android.feature.aichat.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aidatainsight.android.core.model.contract.AIChatIntentType
import com.aidatainsight.android.core.model.contract.ChartPayload
import com.aidatainsight.android.core.model.contract.FeedbackState
import com.aidatainsight.android.core.model.contract.FunctionName
import com.aidatainsight.android.feature.aichat.application.model.SendFunctionMessageOutput
import com.aidatainsight.android.feature.aichat.application.model.UseCaseResult
import com.aidatainsight.android.feature.aichat.application.usecase.LoadChartDataUseCase
import com.aidatainsight.android.feature.aichat.application.usecase.LoadHistoryDetailUseCase
import com.aidatainsight.android.feature.aichat.application.usecase.LoadTemplateUseCase
import com.aidatainsight.android.feature.aichat.application.usecase.SendFunctionMessageUseCase
import com.aidatainsight.android.feature.aichat.application.usecase.SendLikeFeedbackUseCase
import com.aidatainsight.android.feature.aichat.data.DefaultAIChatRepository
import com.aidatainsight.android.feature.aichat.domain.AIChatRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class AIChatViewModel(
    repository: AIChatRepository = DefaultAIChatRepository(),
) : ViewModel() {
    // ViewModel 只编排 UI 状态，具体接口调用和契约转换下沉到 use case / mapper。
    private val loadTemplateUseCase = LoadTemplateUseCase(repository)
    private val loadHistoryDetailUseCase = LoadHistoryDetailUseCase(repository)
    private val sendFunctionMessageUseCase = SendFunctionMessageUseCase(repository)
    private val loadChartDataUseCase = LoadChartDataUseCase(repository)
    private val sendLikeFeedbackUseCase = SendLikeFeedbackUseCase(repository)

    private val _uiState = MutableStateFlow(AIChatUiState())
    val uiState: StateFlow<AIChatUiState> = _uiState.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            // 推荐问题只影响欢迎态，不阻塞已加载的聊天内容。
            _uiState.value = _uiState.value.copy(isLoadingTemplate = true, errorMessage = null)
            runCatching { loadTemplateUseCase() }
                .onSuccess { output ->
                    _uiState.value = _uiState.value.copy(
                        templateQuestions = output.questions,
                        isLoadingTemplate = false,
                    )
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(
                        isLoadingTemplate = false,
                        errorMessage = error.message ?: "加载失败",
                    )
                }
        }
    }

    fun startNewConversation() {
        _uiState.value = AIChatUiState(isLoadingTemplate = true)
        refresh()
    }

    fun loadConversation(historyId: Int) {
        viewModelScope.launch {
            // 切换历史会话时先清空当前输入和消息，避免旧会话内容短暂闪现。
            _uiState.value = _uiState.value.copy(
                historyId = historyId,
                messages = emptyList(),
                templateQuestions = emptyList(),
                input = "",
                isLoadingTemplate = true,
                isSending = false,
                isStreaming = false,
                errorMessage = null,
            )
            runCatching { loadHistoryDetailUseCase(historyId) }
                .onSuccess { output ->
                    loadHistory(output.messages)
                    _uiState.value = _uiState.value.copy(historyId = historyId)
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(
                        isLoadingTemplate = false,
                        errorMessage = error.message ?: "加载历史会话失败",
                    )
                }
        }
    }

    fun updateInput(value: String) {
        _uiState.value = _uiState.value.copy(input = value)
    }

    fun useTemplate(question: String) {
        _uiState.value = _uiState.value.copy(input = question)
    }

    fun sendCurrentMessage() {
        send(_uiState.value.input)
    }

    fun send(text: String) {
        val trimmed = text.trim()
        if (trimmed.isEmpty() || _uiState.value.isLoading) return

        // 先乐观插入用户消息和“思考中”占位，接口返回后再替换占位消息。
        val userMessage = AIChatMessageUiModel(
            id = "local-user-${System.currentTimeMillis()}",
            role = AIChatMessageRoleUi.User,
            text = trimmed,
            contentKind = AIChatMessageContentKindUi.Text,
        )
        val loadingMessage = AIChatMessageUiModel(
            id = "local-assistant-loading-${System.currentTimeMillis()}",
            role = AIChatMessageRoleUi.Assistant,
            text = THINKING_TEXT,
            contentKind = AIChatMessageContentKindUi.Loading,
        )
        _uiState.value = _uiState.value.copy(
            input = "",
            messages = _uiState.value.messages + listOf(userMessage, loadingMessage),
            isSending = true,
            errorMessage = null,
        )

        viewModelScope.launch {
            runCatching {
                when (val result = sendFunctionMessageUseCase(trimmed, _uiState.value.historyId)) {
                    is UseCaseResult.Failure -> {
                        replaceProgressMessage(
                            text = result.message ?: "未找到可用分析结果",
                            contentKind = AIChatMessageContentKindUi.Error,
                        )
                    }
                    is UseCaseResult.Success -> handleFunctionOutput(result.value)
                }
            }.onFailure { error ->
                _uiState.value = _uiState.value.copy(
                    isSending = false,
                    isStreaming = false,
                    errorMessage = error.message ?: "发送失败",
                )
            }
        }
    }

    private suspend fun handleFunctionOutput(output: SendFunctionMessageOutput) {
        when (output) {
            is SendFunctionMessageOutput.Intent -> {
                // 参数不足时展示补充意图，不继续请求图表数据。
                replaceProgressMessage(
                    text = intentText(output.type),
                    contentKind = AIChatMessageContentKindUi.Intent,
                    intentType = output.type,
                )
            }
            is SendFunctionMessageOutput.ChartRequest -> {
                _uiState.value = _uiState.value.copy(historyId = output.historyId)
                // 函数识别成功后再按函数名和参数请求图表详情。
                when (val chartResult = loadChartDataUseCase(output.name, output.historyId, output.arguments)) {
                    is UseCaseResult.Failure -> replaceProgressMessage(
                        text = chartResult.message ?: CHART_FALLBACK_TEXT,
                        contentKind = AIChatMessageContentKindUi.Error,
                        functionName = output.name,
                    )
                    is UseCaseResult.Success -> {
                        val payload = chartResult.value.payload
                        if (payload.series.isEmpty()) {
                            replaceProgressMessage(
                                text = payload.emptyMessage ?: CHART_FALLBACK_TEXT,
                                contentKind = AIChatMessageContentKindUi.Error,
                                functionName = output.name,
                            )
                        } else {
                            replaceProgressMessage(
                                text = CHART_TITLE_TEXT,
                                contentKind = AIChatMessageContentKindUi.Chart,
                                chartPayload = payload,
                                functionName = output.name,
                            )
                        }
                    }
                }
            }
        }
    }

    private fun replaceProgressMessage(
        text: String,
        contentKind: AIChatMessageContentKindUi,
        intentType: AIChatIntentType? = null,
        chartPayload: ChartPayload? = null,
        functionName: FunctionName? = null,
    ) {
        val message = AIChatMessageUiModel(
            id = "local-assistant-${System.currentTimeMillis()}",
            role = AIChatMessageRoleUi.Assistant,
            text = text,
            contentKind = contentKind,
            intentType = intentType,
            chartPayload = chartPayload,
            feedback = FeedbackState.None,
            functionName = functionName,
        )
        val messages = _uiState.value.messages
        val withoutProgress = if (messages.lastOrNull()?.role == AIChatMessageRoleUi.Assistant &&
            messages.lastOrNull()?.contentKind == AIChatMessageContentKindUi.Loading
        ) {
            // 只替换最后一个加载占位，保留前面已经完成的问答。
            messages.dropLast(1)
        } else {
            messages
        }
        _uiState.value = _uiState.value.copy(
            messages = withoutProgress + message,
            isSending = false,
            isStreaming = false,
        )
    }

    private fun intentText(type: AIChatIntentType): String {
        return when (type) {
            AIChatIntentType.Time -> TIME_INTENT_TEXT
            AIChatIntentType.Index -> INDEX_INTENT_TEXT
        }
    }

    fun dismissError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }

    fun sendFeedback(messageId: String, historyDetailId: Int?, feedback: FeedbackState) {
        val detailId = historyDetailId ?: return
        val like = when (feedback) {
            FeedbackState.Liked -> "1"
            FeedbackState.Disliked -> "0"
            else -> return
        }
        val previousMessages = _uiState.value.messages
        // 点赞/点踩采用乐观更新，提交失败再回滚到旧消息列表。
        _uiState.value = _uiState.value.copy(
            messages = previousMessages.map { message ->
                if (message.id == messageId) message.copy(feedback = feedback) else message
            },
            errorMessage = null,
        )
        viewModelScope.launch {
            sendLikeFeedbackUseCase(detailId, like)
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(
                        messages = previousMessages,
                        errorMessage = error.message ?: "操作失败",
                    )
                }
        }
    }

    fun loadHistory(messages: List<com.aidatainsight.android.core.model.contract.ConversationMessage>) {
        _uiState.value = _uiState.value.copy(
            messages = AIChatHistoryMapper.makeMessages(messages),
            errorMessage = null,
            isLoadingTemplate = false,
            isSending = false,
            isStreaming = false,
        )
    }

    companion object {
        const val THINKING_TEXT = "智能引擎全力运转，您的答案即将揭晓。"
        const val CHART_TITLE_TEXT = "根据您的查询，以下是分析结果:"
        const val CHART_FALLBACK_TEXT = "数据分析还在测试阶段，很快就能上线，敬请期待！"
        const val TIME_INTENT_TEXT = "请选择查询时间范围"
        const val INDEX_INTENT_TEXT = "请选择分析指标"
    }
}
