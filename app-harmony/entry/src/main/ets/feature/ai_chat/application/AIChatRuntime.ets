import {
  AIChatIntentType,
  ChartPayload,
  ConversationRole,
  FeedbackState,
  FunctionName
} from '../../../core/model/ContractModelExports'
import {
  AIChatRepository,
  LoadChartDataUseCase,
  LoadChartResultKind,
  LoadHistoryDetailUseCase,
  LoadTemplateUseCase,
  MockAIChatRepository,
  RemoteAIChatRepository,
  SendFunctionMessageUseCase,
  SendFunctionResultKind,
  SendLikeFeedbackUseCase,
  StreamAIResponseUseCase
} from './AIChatRepository'
import {
  AIChatMessageContentKind,
  AIChatMessageUiModel,
  AIChatUiState,
  aiChatChartFallbackText,
  aiChatChartTitle,
  aiChatGenericErrorText,
  buildAIChatUiState,
  initialAIChatUiState,
  makeLoadingMessage,
  makeUserMessage,
  mapConversationMessages,
  replaceLastMessage,
  updateMessageFeedback
} from './AIChatState'
import { appRequester } from '../../../app/services/AppServices'

export type AIChatStateListener = (state: AIChatUiState) => void

export class AIChatRuntimeStore {
  // RuntimeStore 持有 use case 和 UI 状态，页面通过订阅获得状态更新。
  private loadTemplateUseCase: LoadTemplateUseCase
  private loadHistoryDetailUseCase: LoadHistoryDetailUseCase
  private sendFunctionMessageUseCase: SendFunctionMessageUseCase
  private loadChartDataUseCase: LoadChartDataUseCase
  private sendLikeFeedbackUseCase: SendLikeFeedbackUseCase
  private streamAIResponseUseCase: StreamAIResponseUseCase
  private state: AIChatUiState = initialAIChatUiState()
  private messageCounter: number = 0
  private listeners: Array<AIChatStateListener> = new Array<AIChatStateListener>()

  constructor(repository: AIChatRepository = new MockAIChatRepository()) {
    this.loadTemplateUseCase = new LoadTemplateUseCase(repository)
    this.loadHistoryDetailUseCase = new LoadHistoryDetailUseCase(repository)
    this.sendFunctionMessageUseCase = new SendFunctionMessageUseCase(repository)
    this.loadChartDataUseCase = new LoadChartDataUseCase(repository)
    this.sendLikeFeedbackUseCase = new SendLikeFeedbackUseCase(repository)
    this.streamAIResponseUseCase = new StreamAIResponseUseCase(repository)
  }

  snapshot(): AIChatUiState {
    return this.state
  }

  subscribe(listener: AIChatStateListener): () => void {
    this.listeners.push(listener)
    return (): void => {
      // 返回取消订阅函数，页面销毁时调用避免重复通知。
      this.listeners = this.listeners.filter((item: AIChatStateListener): boolean => item !== listener)
    }
  }

  updateInput(text: string): AIChatUiState {
    this.setState(buildAIChatUiState(
      this.state.historyId ?? null,
      this.state.messages,
      this.state.templateQuestions,
      text,
      this.state.isLoadingTemplate,
      this.state.isSending,
      this.state.isStreaming,
      null,
      false
    ))
    return this.state
  }

  async loadTemplate(): Promise<AIChatUiState> {
    // 新会话先加载模板问题，用于欢迎态快捷提问。
    this.state = buildAIChatUiState(null, new Array<AIChatMessageUiModel>(), new Array<string>(), '', true, false, false, null, false)
    try {
      let questions = await this.loadTemplateUseCase.execute()
      this.state = buildAIChatUiState(null, new Array<AIChatMessageUiModel>(), questions, '', false, false, false, null, false)
    } catch (error) {
      this.state = buildAIChatUiState(null, new Array<AIChatMessageUiModel>(), new Array<string>(), '', false, false, false, aiChatGenericErrorText, false)
    }
    return this.state
  }

  async resetConversation(): Promise<AIChatUiState> {
    this.state = initialAIChatUiState()
    return this.loadTemplate()
  }

  async loadHistoryDetail(historyId: number): Promise<AIChatUiState> {
    // 切换历史会话时清空当前消息，加载完成后再展示回放内容。
    this.state = buildAIChatUiState(historyId, new Array<AIChatMessageUiModel>(), new Array<string>(), '', false, true, false, null, false)
    try {
      let messages = mapConversationMessages(await this.loadHistoryDetailUseCase.execute(historyId))
      this.state = buildAIChatUiState(historyId, messages, new Array<string>(), '', false, false, false, null, true)
    } catch (error) {
      this.state = buildAIChatUiState(historyId, new Array<AIChatMessageUiModel>(), new Array<string>(), '', false, false, false, aiChatGenericErrorText, false)
    }
    return this.state
  }

  async sendMessage(text: string): Promise<AIChatUiState> {
    let trimmed = text.trim()
    if (trimmed.length === 0 || this.state.isSending || this.state.isStreaming) {
      return this.state
    }

    // 先插入用户消息和 loading 占位，后续结果回来后替换最后一条消息。
    let userMessage = makeUserMessage(this.nextId('local-user'), trimmed)
    let loadingMessage = makeLoadingMessage(this.nextId('local-assistant-loading'))
    let messages = this.state.messages.concat([userMessage, loadingMessage])
    let activeHistoryId = this.state.historyId ?? null
    this.setState(buildAIChatUiState(activeHistoryId, messages, this.state.templateQuestions, '', false, true, false, null, true))

    let result = await this.sendFunctionMessageUseCase.execute(trimmed, activeHistoryId)
    if (result.kind === SendFunctionResultKind.Intent) {
      // 参数不足时展示补充意图，不继续拉取图表。
      this.setState(buildAIChatUiState(
        activeHistoryId,
        replaceLastMessage(this.state.messages, this.makeIntentMessage(result.text ?? '需要补充查询条件', result.intentType ?? AIChatIntentType.Time)),
        this.state.templateQuestions,
        '',
        false,
        false,
        false,
        null,
        true
      ))
      return this.state
    }

    if (result.kind === SendFunctionResultKind.ChartRequest && result.name !== null && result.name !== undefined && result.historyId !== null && result.historyId !== undefined && result.argumentsValue !== null && result.argumentsValue !== undefined) {
      // 函数识别成功后再请求图表详情，避免函数接口承担大数据返回。
      let chartResult = await this.loadChartDataUseCase.execute(result.name, result.historyId, result.argumentsValue)
      if (chartResult.kind === LoadChartResultKind.Chart && chartResult.payload !== null && chartResult.payload !== undefined) {
        this.setState(buildAIChatUiState(
          result.historyId,
          replaceLastMessage(this.state.messages, this.makeChartMessage(chartResult.payload, result.name, chartResult.historyDetailId ?? null)),
          this.state.templateQuestions,
          '',
          false,
          false,
          false,
          null,
          true
        ))
        return this.state
      }
      this.setState(buildAIChatUiState(
        result.historyId,
        replaceLastMessage(this.state.messages, this.makeErrorMessage(chartResult.message ?? aiChatChartFallbackText, result.name)),
        this.state.templateQuestions,
        '',
        false,
        false,
        false,
        null,
        true
      ))
      return this.state
    }

    await this.streamAnswer(trimmed)
    return this.state
  }

  async sendFeedback(historyDetailId: number, like: string): Promise<AIChatUiState> {
    let target = like === '1' ? FeedbackState.Liked : FeedbackState.Disliked
    let previous = this.state.messages
    // 点赞/点踩先乐观更新，接口失败则恢复之前的消息列表。
    this.state = buildAIChatUiState(
      this.state.historyId ?? null,
      updateMessageFeedback(this.state.messages, historyDetailId, target),
      this.state.templateQuestions,
      this.state.inputText,
      this.state.isLoadingTemplate,
      this.state.isSending,
      this.state.isStreaming,
      null,
      false
    )
    try {
      await this.sendLikeFeedbackUseCase.execute(historyDetailId, like)
    } catch (error) {
      this.state = buildAIChatUiState(
        this.state.historyId ?? null,
        previous,
        this.state.templateQuestions,
        this.state.inputText,
        this.state.isLoadingTemplate,
        this.state.isSending,
        this.state.isStreaming,
        '反馈发送失败',
        false
      )
    }
    return this.state
  }

  private async streamAnswer(text: string): Promise<void> {
    try {
      let responseText = ''
      await this.streamAIResponseUseCase.execute(text, (chunk: string) => {
        // 当前实现先累积完整文本，后续可改为每个 chunk 都 setState 实时刷新。
        responseText += chunk
      })
      if (responseText.length === 0) {
        responseText = '已收到您的问题，当前接口未返回可展示内容，请稍后再试或换一种问法。'
      }
      this.setState(buildAIChatUiState(
        this.state.historyId ?? null,
        replaceLastMessage(this.state.messages, this.makeTextMessage(responseText)),
        this.state.templateQuestions,
        '',
        false,
        false,
        false,
        null,
        true
      ))
    } catch (error) {
      this.setState(buildAIChatUiState(
        this.state.historyId ?? null,
        replaceLastMessage(this.state.messages, this.makeErrorMessage(aiChatGenericErrorText, null)),
        this.state.templateQuestions,
        '',
        false,
        false,
        false,
        null,
        true
      ))
    }
  }

  private setState(state: AIChatUiState): void {
    this.state = state
    this.notify()
  }

  private notify(): void {
    // 逐个通知订阅者，保持页面状态和 runtime 内部状态同步。
    for (let index = 0; index < this.listeners.length; index++) {
      this.listeners[index](this.state)
    }
  }

  private makeIntentMessage(text: string, intentType: AIChatIntentType): AIChatMessageUiModel {
    return {
      id: this.nextId('local-assistant-intent'),
      role: ConversationRole.Assistant,
      contentKind: AIChatMessageContentKind.Intent,
      text: text,
      intentType: intentType,
      feedback: FeedbackState.None,
      templateQuestions: new Array<string>(),
      isStreaming: false
    }
  }

  private makeChartMessage(payload: ChartPayload, functionName: FunctionName, historyDetailId: number | null): AIChatMessageUiModel {
    return {
      id: this.nextId('local-assistant-chart'),
      role: ConversationRole.Assistant,
      contentKind: AIChatMessageContentKind.Chart,
      text: aiChatChartTitle,
      chartPayload: payload,
      feedback: FeedbackState.None,
      historyDetailId: historyDetailId,
      functionName: functionName,
      templateQuestions: new Array<string>(),
      isStreaming: false
    }
  }

  private makeTextMessage(text: string, id?: string): AIChatMessageUiModel {
    return {
      id: id ?? this.nextId('local-assistant-text'),
      role: ConversationRole.Assistant,
      contentKind: AIChatMessageContentKind.Text,
      text: text,
      feedback: FeedbackState.None,
      templateQuestions: new Array<string>(),
      isStreaming: false
    }
  }

  private makeStreamingMessage(text: string, id: string): AIChatMessageUiModel {
    return {
      id: id,
      role: ConversationRole.Assistant,
      contentKind: AIChatMessageContentKind.Text,
      text: text,
      feedback: FeedbackState.None,
      templateQuestions: new Array<string>(),
      isStreaming: true
    }
  }

  private makeErrorMessage(text: string, functionName?: FunctionName | null, id?: string): AIChatMessageUiModel {
    return {
      id: id ?? this.nextId('local-assistant-fallback'),
      role: ConversationRole.Assistant,
      contentKind: AIChatMessageContentKind.Error,
      text: text,
      feedback: FeedbackState.None,
      functionName: functionName ?? null,
      templateQuestions: new Array<string>(),
      isStreaming: false
    }
  }

  private nextId(prefix: string): string {
    // 本地消息 id 单调递增，避免同一轮会话中重复 key。
    this.messageCounter += 1
    return `${prefix}-${this.messageCounter}`
  }
}

export const aiChatRuntimeStore = new AIChatRuntimeStore(new RemoteAIChatRepository(appRequester))
