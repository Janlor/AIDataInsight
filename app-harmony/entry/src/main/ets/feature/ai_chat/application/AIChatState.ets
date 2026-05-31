import {
  AIChatIntentType,
  ChartPayload,
  ConversationContentKind,
  ConversationMessage,
  ConversationRole,
  FeedbackState,
  FunctionName
} from '../../../core/model/ContractModelExports'

export const aiChatThinkingText = '智能引擎全力运转，您的答案即将揭晓。'
export const aiChatChartTitle = '根据您的查询，以下是分析结果:'
export const aiChatChartFallbackText = '数据分析还在测试阶段，很快就能上线，敬请期待！'
export const aiChatGenericErrorText = '这个问题目前无法回答。请尝试以不同的方式重新表述您的问题。'
export const aiChatWelcomeIntro = '你好，我是你的AI数据分析助手。我能根据业绩、库存、代采、应收、帐龄等领域的问题生成相应的智能图表。'
export const aiChatWelcomePrompt = '你也可以尝试点击以下推荐问题：'
export const aiChatInputPlaceholder = '请输入您的数据分析查询。'

// UI 层额外的消息类型，包含本地 loading/error 状态。
export enum AIChatMessageContentKind {
  Welcome = 'welcome',
  Text = 'text',
  Intent = 'intent',
  Chart = 'chart',
  Loading = 'loading',
  Error = 'error'
}

export interface AIChatMessageUiModel {
  id: string
  role: ConversationRole
  contentKind: AIChatMessageContentKind
  text?: string | null
  intentType?: AIChatIntentType | null
  chartPayload?: ChartPayload | null
  feedback: FeedbackState
  historyDetailId?: number | null
  functionName?: FunctionName | null
  templateQuestions: Array<string>
  isStreaming: boolean
}

export interface AIChatUiState {
  historyId?: number | null
  messages: Array<AIChatMessageUiModel>
  templateQuestions: Array<string>
  inputText: string
  isLoadingTemplate: boolean
  isSending: boolean
  isStreaming: boolean
  errorMessage?: string | null
  canSend: boolean
  canClear: boolean
  scrollToBottom: boolean
}

export function initialAIChatUiState(): AIChatUiState {
  // 初始状态不立即放欢迎消息，等待模板问题加载后再构造欢迎态。
  return buildAIChatUiState(null, new Array<AIChatMessageUiModel>(), new Array<string>(), '', false, false, false, null, false)
}

export function buildAIChatUiState(
  historyId: number | null,
  messages: Array<AIChatMessageUiModel>,
  templateQuestions: Array<string>,
  inputText: string,
  isLoadingTemplate: boolean,
  isSending: boolean,
  isStreaming: boolean,
  errorMessage: string | null,
  scrollToBottom: boolean
): AIChatUiState {
  let normalizedInput = inputText.trim()
  // canSend/canClear 是派生状态，统一在这里计算，页面层只负责渲染。
  return {
    historyId: historyId,
    messages: messages,
    templateQuestions: templateQuestions,
    inputText: inputText,
    isLoadingTemplate: isLoadingTemplate,
    isSending: isSending,
    isStreaming: isStreaming,
    errorMessage: errorMessage,
    canSend: normalizedInput.length > 0 && !isSending && !isStreaming,
    canClear: messages.length > 0 || historyId !== null,
    scrollToBottom: scrollToBottom
  }
}

export function makeWelcomeMessage(templateQuestions: Array<string>): AIChatMessageUiModel {
  // 欢迎消息携带推荐问题，页面可直接渲染为快捷入口。
  return {
    id: 'local-welcome',
    role: ConversationRole.Assistant,
    contentKind: AIChatMessageContentKind.Welcome,
    text: aiChatWelcomeIntro,
    feedback: FeedbackState.None,
    templateQuestions: templateQuestions,
    isStreaming: false
  }
}

export function makeUserMessage(id: string, text: string): AIChatMessageUiModel {
  return {
    id: id,
    role: ConversationRole.User,
    contentKind: AIChatMessageContentKind.Text,
    text: text,
    feedback: FeedbackState.None,
    templateQuestions: new Array<string>(),
    isStreaming: false
  }
}

export function makeLoadingMessage(id: string): AIChatMessageUiModel {
  return {
    id: id,
    role: ConversationRole.Assistant,
    contentKind: AIChatMessageContentKind.Loading,
    text: aiChatThinkingText,
    feedback: FeedbackState.None,
    templateQuestions: new Array<string>(),
    isStreaming: false
  }
}

export function mapConversationMessages(messages: Array<ConversationMessage>): Array<AIChatMessageUiModel> {
  // 历史详情回放时，把跨端契约消息转换成 Harmony 页面模型。
  return messages.map((message: ConversationMessage): AIChatMessageUiModel => {
    return {
      id: message.id,
      role: message.role,
      contentKind: mapContentKind(message.contentKind),
      text: message.contentKind === ConversationContentKind.Chart ? aiChatChartTitle : message.text ?? null,
      intentType: message.intentType ?? null,
      chartPayload: message.chartPayload ?? null,
      feedback: message.feedback,
      historyDetailId: message.historyDetailId ?? null,
      functionName: message.functionName ?? null,
      templateQuestions: new Array<string>(),
      isStreaming: false
    }
  })
}

export function mapContentKind(kind: ConversationContentKind): AIChatMessageContentKind {
  if (kind === ConversationContentKind.Chart) {
    return AIChatMessageContentKind.Chart
  }
  if (kind === ConversationContentKind.Intent) {
    return AIChatMessageContentKind.Intent
  }
  if (kind === ConversationContentKind.Welcome) {
    return AIChatMessageContentKind.Welcome
  }
  return AIChatMessageContentKind.Text
}

export function replaceLastMessage(
  messages: Array<AIChatMessageUiModel>,
  replacement: AIChatMessageUiModel
): Array<AIChatMessageUiModel> {
  // 发送过程中最后一条通常是 loading，占位消息返回后用真实结果替换。
  let updated = messages.slice()
  if (updated.length === 0) {
    updated.push(replacement)
    return updated
  }
  updated.splice(updated.length - 1, 1, replacement)
  return updated
}

export function updateMessageFeedback(
  messages: Array<AIChatMessageUiModel>,
  historyDetailId: number,
  feedback: FeedbackState
): Array<AIChatMessageUiModel> {
  // 点赞/点踩只更新匹配 historyDetailId 的助手消息。
  return messages.map((message: AIChatMessageUiModel): AIChatMessageUiModel => {
    if (message.historyDetailId !== historyDetailId) {
      return message
    }
    return {
      id: message.id,
      role: message.role,
      contentKind: message.contentKind,
      text: message.text ?? null,
      intentType: message.intentType ?? null,
      chartPayload: message.chartPayload ?? null,
      feedback: feedback,
      historyDetailId: message.historyDetailId ?? null,
      functionName: message.functionName ?? null,
      templateQuestions: message.templateQuestions,
      isStreaming: message.isStreaming
    }
  })
}
