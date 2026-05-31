import AppContracts
import AppCore
import AppDesignSystem
import AppNetworking
import Charts
import Foundation
import Observation
import SwiftUI

/// 助手需要用户补充的意图类型，目前用于时间范围和指标类型选择。
public enum AIChatIntentType: String, Equatable, Sendable {
    case time
    case index
}

/// 聊天消息在界面上的展示形态。
public enum ChatMessageContentKind: Equatable, Sendable {
    case text
    case chart
    case intent
    case welcome
}

/// 单条回答的反馈状态，对应点赞、点踩和服务端未知值。
public enum FeedbackState: Equatable, Sendable {
    case liked
    case disliked
    case none
    case unknown
}

/// 图表数值单位，影响轴标签和 tooltip 的格式化。
public enum ChartUnit: Equatable, Sendable {
    case currency
    case ton
}

/// 一组可绘制的图表序列，xAxis 表示当前分组名，labels/values 保持同下标对应。
public struct ChartSeriesViewState: Identifiable, Equatable, Sendable {
    public let id: String
    public let xAxis: String
    public let labels: [String]
    public let values: [Double]

    public init(id: String = UUID().uuidString, xAxis: String, labels: [String], values: [Double]) {
        self.id = id
        self.xAxis = xAxis
        self.labels = labels
        self.values = values
    }
}

/// 图表消息的视图载荷，把后端图表明细整理成 UI 可直接消费的序列。
public struct ChartPayloadViewState: Equatable, Sendable {
    public let functionName: FunctionNameContract?
    public let unit: ChartUnit
    public let series: [ChartSeriesViewState]
    public let emptyMessage: String?

    public init(functionName: FunctionNameContract?, unit: ChartUnit, series: [ChartSeriesViewState], emptyMessage: String? = nil) {
        self.functionName = functionName
        self.unit = unit
        self.series = series
        self.emptyMessage = emptyMessage
    }

    public init(detail: HistoryChartDetailContract, fallbackName: FunctionNameContract? = nil) {
        if let first = detail.accountAgeGroupVoList?.first, first.chartType == "2", let msg = first.msg {
            // 账龄接口用 chartType == "2" 表示无图表但有说明文案，UI 按普通文本提示展示。
            self.init(functionName: detail.funcType ?? fallbackName, unit: .currency, series: [], emptyMessage: msg)
            return
        }

        let accountAgeSeries = (detail.accountAgeGroupVoList ?? []).map {
            ChartSeriesViewState(xAxis: $0.name ?? "", labels: $0.labelList ?? [], values: $0.valueList ?? [])
        }
        let commonSeries = (detail.chartCommonVoList ?? []).map {
            ChartSeriesViewState(xAxis: $0.name ?? "", labels: [$0.name ?? ""], values: [$0.value ?? 0])
        }
        let functionName = detail.funcType ?? fallbackName
        self.init(
            functionName: functionName,
            unit: functionName?.usesTon == true ? .ton : .currency,
            series: accountAgeSeries + commonSeries
        )
    }
}

/// 聊天页的单条消息状态，兼容普通文本、意图补充和图表回答。
public struct ChatMessageViewState: Identifiable, Equatable, Sendable {
    public enum Role: Equatable, Sendable {
        case user
        case assistant
    }

    public let id: String
    public let role: Role
    public var contentKind: ChatMessageContentKind
    public var text: String
    public var intentType: AIChatIntentType?
    public var chartPayload: ChartPayloadViewState?
    public var feedback: FeedbackState
    public var historyDetailID: Int?
    public var functionName: FunctionNameContract?

    public init(
        id: String = UUID().uuidString,
        role: Role,
        contentKind: ChatMessageContentKind = .text,
        text: String,
        intentType: AIChatIntentType? = nil,
        chartPayload: ChartPayloadViewState? = nil,
        feedback: FeedbackState = .none,
        historyDetailID: Int? = nil,
        functionName: FunctionNameContract? = nil
    ) {
        self.id = id
        self.role = role
        self.contentKind = contentKind
        self.text = text
        self.intentType = intentType
        self.chartPayload = chartPayload
        self.feedback = feedback
        self.historyDetailID = historyDetailID
        self.functionName = functionName
    }
}

/// 聊天页整体状态，Store 只通过该结构暴露可观察数据。
public struct AIChatViewState: Equatable, Sendable {
    public var messages: [ChatMessageViewState]
    public var draft: String
    public var templateQuestions: [String]
    public var activeHistoryID: Int?
    public var activeHistoryTitle: String?
    public var isLoadingTemplate: Bool
    public var isSending: Bool
    public var showsWelcome: Bool
    public var errorMessage: String?

    public init(
        messages: [ChatMessageViewState] = [],
        draft: String = "",
        templateQuestions: [String] = [],
        activeHistoryID: Int? = nil,
        activeHistoryTitle: String? = nil,
        isLoadingTemplate: Bool = false,
        isSending: Bool = false,
        showsWelcome: Bool = true,
        errorMessage: String? = nil
    ) {
        self.messages = messages
        self.draft = draft
        self.templateQuestions = templateQuestions
        self.activeHistoryID = activeHistoryID
        self.activeHistoryTitle = activeHistoryTitle
        self.isLoadingTemplate = isLoadingTemplate
        self.isSending = isSending
        self.showsWelcome = showsWelcome
        self.errorMessage = errorMessage
    }

    public var displayTitle: String {
        guard let title = activeHistoryTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              title.isEmpty == false
        else {
            return "AI数据分析助手"
        }
        return title
    }
}

/// AI 问答领域仓库协议，隐藏模板、历史、函数调用、图表和反馈的具体来源。
public protocol AIChatRepository: Sendable {
    func loadTemplate() async throws -> TemplateQuestionSetContract
    func loadHistoryDetail(historyId: Int) async throws -> HistoryRecordContract
    func sendFunctionMessage(text: String, historyId: Int?) async throws -> FunctionModelContract
    func loadChartData(name: FunctionNameContract, historyId: Int, arguments: FunctionArgumentsContract) async throws -> HistoryChartDetailContract
    func sendLikeFeedback(historyDetailId: Int, like: String) async throws
    func streamMessage(text: String) -> AsyncThrowingStream<String, Error>
}

/// 真实后端仓库实现，负责把 UI 操作翻译成对应接口请求。
public struct RemoteAIChatRepository: AIChatRepository {
    private let client: HTTPClient
    private let streamer: SSEStreaming?

    public init(client: HTTPClient, streamer: SSEStreaming? = nil) {
        self.client = client
        self.streamer = streamer
    }

    public func loadTemplate() async throws -> TemplateQuestionSetContract {
        let envelope = try await client.send(HTTPRequest(path: "/chat/template"), as: TemplateQuestionPayload.self)
        guard let payload = envelope.data else {
            throw AppError(kind: .dataFormat, traceID: envelope.trace, transactionID: envelope.tid)
        }
        return payload.value
    }

    public func loadHistoryDetail(historyId: Int) async throws -> HistoryRecordContract {
        let envelope = try await client.send(
            HTTPRequest(path: "/history/detail", queryItems: [HTTPQueryItem(name: "historyId", value: String(historyId))]),
            as: HistoryRecordContract.self
        )
        guard let record = envelope.data else {
            throw AppError(kind: .dataFormat, traceID: envelope.trace, transactionID: envelope.tid)
        }
        return record
    }

    public func sendFunctionMessage(text: String, historyId: Int?) async throws -> FunctionModelContract {
        var queryItems = [HTTPQueryItem(name: "question", value: text)]
        if let historyId {
            queryItems.append(HTTPQueryItem(name: "historyId", value: String(historyId)))
        }
        let envelope = try await client.send(HTTPRequest(path: "/chat/function", queryItems: queryItems), as: FunctionModelContract.self)
        guard let model = envelope.data else {
            throw AppError(kind: .dataFormat, traceID: envelope.trace, transactionID: envelope.tid)
        }
        return model
    }

    public func loadChartData(name: FunctionNameContract, historyId: Int, arguments: FunctionArgumentsContract) async throws -> HistoryChartDetailContract {
        let envelope = try await client.send(
            HTTPRequest(
                path: "/chart/\(name.rawValue)",
                queryItems: [HTTPQueryItem(name: "historyId", value: String(historyId))] + arguments.queryItems
            ),
            as: HistoryChartDetailContract.self
        )
        guard let detail = envelope.data else {
            throw AppError(kind: .dataFormat, traceID: envelope.trace, transactionID: envelope.tid)
        }
        return detail
    }

    public func sendLikeFeedback(historyDetailId: Int, like: String) async throws {
        let body = try JSONEncoder().encode(LikeHistoryDetailRequestContract(historyDetailId: historyDetailId, like: like))
        _ = try await client.send(
            HTTPRequest(path: "/history/like", method: .post, headers: ["Content-Type": "application/json"], body: body),
            as: EmptyContract.self
        )
    }

    public func streamMessage(text: String) -> AsyncThrowingStream<String, Error> {
        guard let streamer else {
            return AsyncThrowingStream { continuation in
                continuation.finish()
            }
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in streamer.stream(HTTPRequest(path: "/stream", queryItems: [HTTPQueryItem(name: "question", value: text)])) {
                        continuation.yield(event.data)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// 聊天状态机，串联“用户问题 -> 函数识别 -> 参数补全 -> 图表数据 -> 回答展示”的流程。
@MainActor
@Observable
public final class AIChatStore {
    public private(set) var state: AIChatViewState
    private let repository: AIChatRepository
    private var streamTask: Task<Void, Never>?

    public init(state: AIChatViewState = AIChatViewState(), repository: AIChatRepository = PreviewAIChatRepository()) {
        self.state = state
        self.repository = repository
    }

    public var messages: [ChatMessageViewState] {
        state.messages
    }

    public func loadTemplate() async {
        guard state.templateQuestions.isEmpty else {
            return
        }
        state.isLoadingTemplate = true
        state.errorMessage = nil
        do {
            state.templateQuestions = try await repository.loadTemplate().questions
        } catch {
            state.errorMessage = "推荐问题加载失败"
        }
        state.isLoadingTemplate = false
    }

    public func startNewChat() {
        streamTask?.cancel()
        state.messages.removeAll()
        state.draft = ""
        state.activeHistoryID = nil
        state.activeHistoryTitle = nil
        state.showsWelcome = true
        state.errorMessage = nil
    }

    public func updateDraft(_ draft: String) {
        state.draft = draft
        state.errorMessage = nil
    }

    public func appendUserMessage(_ text: String) {
        state.messages.append(ChatMessageViewState(role: .user, text: text))
    }

    public func sendTemplateQuestion(_ text: String) async {
        state.draft = text
        await sendCurrentMessage(allowStreamFallback: false)
    }

    public func sendCurrentMessage() async {
        await sendCurrentMessage(allowStreamFallback: true)
    }

    private func sendCurrentMessage(allowStreamFallback: Bool) async {
        let text = state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false, state.isSending == false else {
            return
        }

        appendUserMessage(text)
        state.draft = ""
        if state.activeHistoryTitle == nil {
            state.activeHistoryTitle = text
        }
        state.isSending = true
        state.errorMessage = nil

        do {
            let function = try await repository.sendFunctionMessage(text: text, historyId: state.activeHistoryID)
            state.activeHistoryID = function.historyId ?? state.activeHistoryID
            try await handle(function: function)
        } catch {
            // 模板问题是结构化入口，失败时直接给兜底文案；自由输入可尝试 SSE 文本流回退。
            if allowStreamFallback {
                await streamFallbackResponse(for: text)
            } else {
                appendAssistantText("这个问题目前无法回答。请尝试以不同的方式重新表述您的问题。")
            }
        }

        state.isSending = false
    }

    public func loadHistory(historyID: Int) async {
        state.errorMessage = nil
        do {
            let record = try await repository.loadHistoryDetail(historyId: historyID)
            state.activeHistoryID = record.id
            state.activeHistoryTitle = record.name
            state.showsWelcome = false
            state.messages = (record.detailList ?? []).map(ChatMessageViewState.init(contract:))
        } catch {
            state.errorMessage = "历史会话加载失败"
        }
    }

    public func sendFeedback(messageID: String, like: String) async {
        guard let index = state.messages.firstIndex(where: { $0.id == messageID }),
              let historyDetailID = state.messages[index].historyDetailID
        else {
            return
        }
        let nextFeedback: FeedbackState = like == "1" ? .liked : .disliked
        guard state.messages[index].feedback != nextFeedback else {
            return
        }
        let previousFeedback = state.messages[index].feedback
        state.messages[index].feedback = nextFeedback
        do {
            try await repository.sendLikeFeedback(historyDetailId: historyDetailID, like: like)
        } catch {
            if let rollbackIndex = state.messages.firstIndex(where: { $0.id == messageID }) {
                state.messages[rollbackIndex].feedback = previousFeedback
            }
            state.errorMessage = "反馈提交失败"
        }
    }

    private func handle(function: FunctionModelContract) async throws {
        guard let historyID = function.historyId else {
            throw AppError(kind: .dataFormat)
        }
        guard function.hasTool == true, let name = function.name, let arguments = function.arguments else {
            appendAssistantText(function.msg ?? "暂时无法完成该分析")
            return
        }

        if case .timeRange(let value) = arguments, value.startDate == nil {
            // 后端识别出时间类问题但缺少时间范围时，先让用户补充参数，不直接请求图表。
            appendAssistantIntent(text: function.msg ?? "请选择时间范围", intentType: .time)
            return
        }

        if case .performanceType = arguments {
            // 经营指标类问题需要用户选择指标口径，再继续后续分析。
            appendAssistantIntent(text: function.msg ?? "请选择指标类型", intentType: .index)
            return
        }

        let chartDetail = try await repository.loadChartData(name: name, historyId: historyID, arguments: arguments)
        let payload = ChartPayloadViewState(detail: chartDetail, fallbackName: name)
        guard payload.emptyMessage == nil, payload.series.isEmpty == false else {
            appendAssistantText(payload.emptyMessage ?? "数据分析还在测试阶段，很快就能上线，敬请期待！")
            return
        }
        state.messages.append(ChatMessageViewState(
            role: .assistant,
            contentKind: .chart,
            text: "根据您的查询，以下是分析结果:",
            chartPayload: payload,
            feedback: .none,
            historyDetailID: chartDetail.historyDetailId,
            functionName: payload.functionName
        ))
    }

    private func streamFallbackResponse(for text: String) async {
        let assistantID = UUID().uuidString
        state.messages.append(ChatMessageViewState(id: assistantID, role: .assistant, text: ""))
        do {
            for try await chunk in repository.streamMessage(text: text) {
                if let index = state.messages.firstIndex(where: { $0.id == assistantID }) {
                    state.messages[index].text += chunk
                }
            }
            if let index = state.messages.firstIndex(where: { $0.id == assistantID }), state.messages[index].text.isEmpty {
                state.messages[index].text = "暂时无法完成该分析"
            }
        } catch {
            if let index = state.messages.firstIndex(where: { $0.id == assistantID }) {
                state.messages[index].text = "暂时无法完成该分析"
            }
        }
    }

    private func appendAssistantText(_ text: String) {
        state.messages.append(ChatMessageViewState(role: .assistant, text: text))
    }

    private func appendAssistantIntent(text: String, intentType: AIChatIntentType) {
        state.messages.append(ChatMessageViewState(role: .assistant, contentKind: .intent, text: text, intentType: intentType))
    }
}

/// 聊天主界面，包含消息列表、欢迎态、模板问题和底部输入区。
public struct AIChatScreen: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var isComposerFocused: Bool
    @Bindable private var store: AIChatStore
    private let account: AccountDisplayState
    private let bottomAnchorID = "chat-bottom-anchor"

    public init(store: AIChatStore, account: AccountDisplayState = .placeholder) {
        self.store = store
        self.account = account
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
            composer
        }
        .background(chatBackground)
        .navigationTitle(store.state.displayTitle)
#if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .accessibilityIdentifier("ai-chat-screen")
#if os(macOS)
        .navigationSubtitle(store.state.activeHistoryID == nil ? "New Chat" : "History")
#endif
        .task {
            await store.loadTemplate()
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 18) {
                    if store.state.showsWelcome {
                        welcomeBubble
                            .id("welcome-bubble")
                    }
                    ForEach(store.state.messages) { message in
                        messageView(message)
                            .id(message.id)
                    }
                    if store.state.isSending {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("分析中...")
                                .foregroundStyle(AppColor.Label.secondary.color)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorID)
                }
                .padding(.horizontal, transcriptHorizontalPadding)
                .padding(.vertical, transcriptVerticalPadding)
                .frame(maxWidth: transcriptMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dismissesKeyboardInteractively()
            .simultaneousGesture(TapGesture().onEnded {
                isComposerFocused = false
            })
            .onAppear {
                scrollToBottom(proxy)
            }
            .onChange(of: store.state.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: store.state.messages.last?.text) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: store.state.isSending) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let errorMessage = store.state.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(AppColor.Status.mark.color)
                    .frame(maxWidth: 860, alignment: .leading)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("请输入您的数据分析查询。", text: Binding(
                    get: { store.state.draft },
                    set: { store.updateDraft($0) }
                ), axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .focused($isComposerFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .accessibilityIdentifier("chat-composer-input")

                Button {
                    isComposerFocused = false
                    Task {
                        await store.sendCurrentMessage()
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: sendButtonIconSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: sendButtonSide, height: sendButtonSide)
                        .background(sendButtonBackground, in: sendButtonShape)
                        .contentShape(sendButtonShape)
                }
                .help("发送")
                .disabled(canSendMessage == false)
                .buttonStyle(.plain)
                .transaction { transaction in
                    transaction.animation = nil
                }
                .accessibilityIdentifier("chat-send-button")
            }
            .padding(6)
            .frame(maxWidth: 860)
            .modifier(ComposerContainerStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(.bar)
    }

    private var welcomeBubble: some View {
        HStack(alignment: .top, spacing: 12) {
            if usesCompactMessageLayout == false {
                avatar(systemName: "sparkles", color: AppColor.Accent.primary.color)
            }
            VStack(alignment: .leading, spacing: 16) {
                Text("你好，我是你的AI数据分析助手。我能根据业绩、库存、代采、应收、帐龄等领域的问题生成相应的智能图表。")
                    .font(.body)
                    .foregroundStyle(AppColor.Label.primary.color)

                VStack(alignment: .leading, spacing: 8) {
                    Text("你也可以尝试点击以下推荐问题：")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.Label.secondary.color)
                    if store.state.isLoadingTemplate {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        ForEach(store.state.templateQuestions, id: \.self) { question in
                            Button {
                                Task {
                                    await store.sendTemplateQuestion(question)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Text(question)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 8)
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .foregroundStyle(AppColor.Label.secondary.color)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 9)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("我能精准识别问题中的指标名称、时间范围、分组维度和过滤条件，例如：")
                        .font(.subheadline.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 8)], alignment: .leading, spacing: 8) {
                        exampleSegment("今年第一季度", caption: "时间范围")
                        exampleSegment("销售额", caption: "指标名称")
                        exampleSegment("大于5000万", caption: "过滤条件")
                        exampleSegment("公司", caption: "分组维度")
                    }
                }
            }
            .padding(16)
            .background(AppColor.GroupedBackground.secondary.elevatedColor, in: UnevenRoundedRectangle(topLeadingRadius: 21, bottomLeadingRadius: 4, bottomTrailingRadius: 21, topTrailingRadius: 21))
            .overlay {
                UnevenRoundedRectangle(topLeadingRadius: 21, bottomLeadingRadius: 4, bottomTrailingRadius: 21, topTrailingRadius: 21)
                    .stroke(AppColor.Separator.default.color)
            }
            .frame(maxWidth: usesCompactMessageLayout ? .infinity : nil, alignment: .leading)
            if usesCompactMessageLayout == false {
                Spacer(minLength: 0)
            }
        }
        .accessibilityIdentifier("ai-chat-welcome-bubble")
    }

    private func exampleSegment(_ title: String, caption: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(AppColor.Label.secondary.color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(AppColor.Accent.secondary.color, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func messageView(_ message: ChatMessageViewState) -> some View {
        if usesCompactMessageLayout {
            compactMessageView(message)
        } else {
            regularMessageView(message)
        }
    }

    private func regularMessageView(_ message: ChatMessageViewState) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                avatar(systemName: "sparkles", color: AppColor.Accent.primary.color)
            } else {
                Spacer(minLength: 80)
            }

            messageBubble(message)
            .padding(14)
            .background(messageBackground(for: message), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(messageBorder(for: message))
            }
            .frame(maxWidth: 680, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user {
                AccountInitialsAvatar(account: account, size: 28)
            } else {
                Spacer(minLength: 80)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("chat-message-\(message.id)")
    }

    private func compactMessageView(_ message: ChatMessageViewState) -> some View {
        messageBubble(message)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(messageBackground(for: message), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(messageBorder(for: message))
            }
            .accessibilityIdentifier("chat-message-\(message.id)")
    }

    private func messageBubble(_ message: ChatMessageViewState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message.text)
                .foregroundStyle(AppColor.Label.primary.color)
                .textSelection(.enabled)

            if let chartPayload = message.chartPayload {
                chartSummary(chartPayload)
            }

            if message.contentKind == .chart, message.historyDetailID != nil {
                feedbackToolbar(for: message)
            }
        }
    }

    private func messageBackground(for message: ChatMessageViewState) -> Color {
        message.role == .user ? AppColor.Accent.secondary.color : AppColor.GroupedBackground.secondary.elevatedColor
    }

    private func messageBorder(for message: ChatMessageViewState) -> Color {
        message.role == .user ? AppColor.Accent.primary.color.opacity(0.10) : AppColor.Separator.default.color
    }

    private func feedbackToolbar(for message: ChatMessageViewState) -> some View {
        HStack(spacing: 8) {
            Spacer()
            feedbackButton(systemName: "hand.thumbsup", selectedSystemName: "hand.thumbsup.fill", isSelected: message.feedback == .liked, help: "有帮助") {
                Task {
                    await store.sendFeedback(messageID: message.id, like: "1")
                }
            }
            feedbackButton(systemName: "hand.thumbsdown", selectedSystemName: "hand.thumbsdown.fill", isSelected: message.feedback == .disliked, help: "没有帮助") {
                Task {
                    await store.sendFeedback(messageID: message.id, like: "0")
                }
            }
        }
        .accessibilityIdentifier("chart-feedback-\(message.id)")
    }

    private func feedbackButton(systemName: String, selectedSystemName: String, isSelected: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isSelected ? selectedSystemName : systemName)
                .frame(width: 28, height: 28)
                .foregroundStyle(isSelected ? AppColor.Accent.primary.color : AppColor.Label.secondary.color)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func chartSummary(_ payload: ChartPayloadViewState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(payload.functionName?.displayName ?? "分析图表")
                    .font(.headline)
                Spacer()
                Text(payload.unitLabel)
                    .font(.caption)
                    .foregroundStyle(AppColor.Label.secondary.color)
            }

            if payload.series.isEmpty {
                Text(payload.emptyMessage ?? "数据分析还在测试阶段，很快就能上线，敬请期待！")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.Label.secondary.color)
            } else {
                let rows = chartRows(for: payload)
                Chart(rows) { row in
                    BarMark(
                        x: .value("分组", row.xAxis),
                        y: .value("数值", row.scaledValue),
                        stacking: .standard
                    )
                    .foregroundStyle(by: .value("图例", row.label))
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartForegroundStyleScale(
                    domain: rows.map(\.label),
                    range: rows.map { AppChartPalette.color(at: $0.colorIndex) }
                )
                .chartLegend(payload.hasStackedSeries ? .visible : .hidden)
                .frame(height: 220)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(rows) { row in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(AppChartPalette.color(at: row.colorIndex))
                                .frame(width: 7, height: 7)
                            Text(row.summaryLabel)
                                .lineLimit(1)
                            Spacer()
                            Text(row.scaledValue.formatted(.number.precision(.fractionLength(0...2))))
                                .foregroundStyle(AppColor.Label.secondary.color)
                        }
                    }
                }
                .font(.caption)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.GroupedBackground.tertiary.color, in: RoundedRectangle(cornerRadius: 8))
    }

    private func chartRows(for payload: ChartPayloadViewState) -> [ChartRowViewState] {
        payload.series.enumerated().flatMap { seriesIndex, series in
            let labels = series.labels.isEmpty ? [series.xAxis] : series.labels
            return labels.enumerated().map { valueIndex, label in
                let rawValue = series.values.indices.contains(valueIndex) ? series.values[valueIndex] : 0
                return ChartRowViewState(
                    xAxis: series.xAxis.isEmpty ? "未命名" : series.xAxis,
                    label: label.isEmpty ? series.xAxis : label,
                    rawValue: rawValue,
                    colorIndex: valueIndex + seriesIndex
                )
            }
        }
    }

    private func avatar(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.12), in: Circle())
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        Task { @MainActor in
            withAnimation(.snappy(duration: 0.22)) {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        }
    }

    private var usesCompactMessageLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var canSendMessage: Bool {
        store.state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && store.state.isSending == false
    }

    private var sendButtonBackground: Color {
        canSendMessage ? AppColor.Accent.primary.color : AppColor.Label.quaternary.color.opacity(0.35)
    }

    private var chatBackground: some View {
        LinearGradient(
            colors: [
                AppColor.GroupedBackground.primary.color,
                AppColor.Background.primary.color,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var sendButtonSide: CGFloat {
#if os(macOS)
        34
#else
        46
#endif
    }

    private var sendButtonIconSize: CGFloat {
#if os(macOS)
        14
#else
        18
#endif
    }

    private var sendButtonShape: some InsettableShape {
#if os(macOS)
        RoundedRectangle(cornerRadius: 8)
#else
        Circle()
#endif
    }

    private var transcriptHorizontalPadding: CGFloat {
        usesCompactMessageLayout ? 12 : 32
    }

    private var transcriptVerticalPadding: CGFloat {
        usesCompactMessageLayout ? 16 : 24
    }

    private var transcriptMaxWidth: CGFloat? {
        usesCompactMessageLayout ? .infinity : 900
    }
}

private struct ComposerContainerStyle: ViewModifier {
    func body(content: Content) -> some View {
#if os(macOS)
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        content
            .background(AppColor.GroupedBackground.secondary.elevatedColor, in: shape)
            .overlay {
                shape.stroke(AppColor.Separator.default.color)
            }
#else
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        content
            .background(AppColor.GroupedBackground.secondary.elevatedColor, in: shape)
            .overlay {
                shape.stroke(AppColor.Separator.default.color)
            }
#endif
    }
}

private extension View {
    @ViewBuilder
    func dismissesKeyboardInteractively() -> some View {
#if os(iOS)
        scrollDismissesKeyboard(.interactively)
#else
        self
#endif
    }
}

private struct TemplateQuestionPayload: Decodable, Sendable {
    let value: TemplateQuestionSetContract

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(TemplateQuestionSetContract.self) {
            self.value = value
            return
        }
        let string = try container.decode(String.self)
        guard let data = string.data(using: .utf8) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid template JSON string.")
        }
        value = try JSONDecoder().decode(TemplateQuestionSetContract.self, from: data)
    }
}

private extension ChatMessageViewState {
    /// 将历史详情转换成当前消息模型，保留后端点赞状态和图表标记。
    init(contract: HistoryDetailContract) {
        let role: Role = contract.type == .question ? .user : .assistant
        let contentKind: ChatMessageContentKind = contract.contentType == .chart ? .chart : .text
        let chartDetail = contract.chartDetail
        let payload = chartDetail.map { ChartPayloadViewState(detail: $0) }
        let text = if contentKind == .chart, payload?.series.isEmpty == false {
            "根据您的查询，以下是分析结果:"
        } else if contentKind == .chart {
            payload?.emptyMessage ?? "数据分析还在测试阶段，很快就能上线，敬请期待！"
        } else {
            contract.content ?? ""
        }
        self.init(
            id: contract.id.map(String.init) ?? UUID().uuidString,
            role: role,
            contentKind: contentKind,
            text: text,
            chartPayload: payload?.series.isEmpty == false ? payload : nil,
            feedback: FeedbackState(contractLike: contract.isLike),
            historyDetailID: contract.id,
            functionName: payload?.functionName
        )
    }
}

private extension HistoryDetailContract {
    /// 历史图表内容里目前保存的是可解码的图表详情 JSON。
    var chartDetail: HistoryChartDetailContract? {
        guard contentType == .chart, let content, let data = content.data(using: .utf8) else {
            return nil
        }
        guard let detail = try? JSONDecoder().decode(HistoryChartDetailContract.self, from: data) else {
            return nil
        }
        return HistoryChartDetailContract(
            historyDetailId: detail.historyDetailId ?? id,
            funcType: detail.funcType,
            chartCommonVoList: detail.chartCommonVoList,
            accountAgeGroupVoList: detail.accountAgeGroupVoList
        )
    }
}

private extension FeedbackState {
    init(contractLike: String?) {
        switch contractLike {
        case "1":
            self = .liked
        case "0":
            self = .disliked
        case nil:
            self = .none
        default:
            self = .unknown
        }
    }
}

private extension FunctionNameContract {
    /// 库存类接口以吨为单位，其余经营分析默认按金额展示。
    var usesTon: Bool {
        self == .queryStockGroupByOrg || self == .queryStockGroupByWarehouse
    }

    var displayName: String {
        switch self {
        case .queryArGroupByOrg:
            "组织应收账款"
        case .queryArGroupByCustomer:
            "客户应收账款"
        case .querySalesGroupByOrgAndGoodsType:
            "组织品类销售额"
        case .querySalesGroupByMonth:
            "月度销售额"
        case .querySalesGroupByCustomer:
            "客户销售额"
        case .queryPurchaseGroupByOrg:
            "组织采购额"
        case .queryPurchaseGroupByMonth:
            "月度采购额"
        case .queryPurchaseGroupByCustomer:
            "客户采购额"
        case .queryStockGroupByOrg:
            "组织库存"
        case .queryStockGroupByWarehouse:
            "仓库库存"
        case .queryInventoryGroupByOrg:
            "组织存货"
        case .queryInventoryGroupByWarehouse:
            "仓库存货"
        case .queryProcurementGroupByOrg:
            "组织代采"
        case .queryProcurementGroupByCustomer:
            "客户代采"
        case .queryAccountAgeGroupByOrg:
            "组织账龄"
        case .queryAccountAgeGroupByCustomer:
            "客户账龄"
        case .queryAccountGroupByAge:
            "账龄分布"
        case .queryPerformanceType:
            "业绩指标"
        }
    }
}

private extension ChartPayloadViewState {
    var unitLabel: String {
        unit == .ton ? "单位：万吨" : "单位：万元"
    }

    var hasStackedSeries: Bool {
        series.contains { $0.values.count > 1 || $0.labels.count > 1 }
    }
}

private struct ChartRowViewState: Identifiable {
    let id = UUID()
    let xAxis: String
    let label: String
    let rawValue: Double
    let colorIndex: Int

    var scaledValue: Double {
        rawValue / 10_000
    }

    var summaryLabel: String {
        label == xAxis ? xAxis : "\(xAxis) · \(label)"
    }
}

private extension AppChartPalette {
    static func color(at index: Int) -> Color {
        let token: AppColorToken
        switch index % order.count {
        case 1:
            token = cyan
        case 2:
            token = mint
        case 3:
            token = green
        case 4:
            token = purple
        case 5:
            token = orange
        case 6:
            token = coral
        default:
            token = blue
        }
        return token.color
    }
}

private extension FunctionArgumentsContract {
    /// 将不同函数参数统一转换为 queryItems，供图表接口复用。
    var queryItems: [HTTPQueryItem] {
        switch self {
        case .basic(let value):
            value.queryItems
        case .timeRange(let value):
            value.queryItems
        case .warehouse(let value):
            value.queryItems
        case .accountAge(let value):
            value.queryItems
        case .performanceType(let value):
            value.queryItems
        }
    }
}

private extension BasicQueryContract {
    var queryItems: [HTTPQueryItem] {
        [
            HTTPQueryItem(name: "orgId", value: orgId.map(String.init)),
            HTTPQueryItem(name: "customerName", value: customerName),
            HTTPQueryItem(name: "orderType", value: orderType),
            HTTPQueryItem(name: "operator", value: `operator`),
            HTTPQueryItem(name: "value", value: value.map { String($0) }),
        ].compactValueItems
    }
}

private extension TimeRangeQueryContract {
    var queryItems: [HTTPQueryItem] {
        [
            HTTPQueryItem(name: "startDate", value: startDate),
            HTTPQueryItem(name: "endDate", value: endDate),
            HTTPQueryItem(name: "orgId", value: orgId.map(String.init)),
            HTTPQueryItem(name: "customerName", value: customerName),
            HTTPQueryItem(name: "goodsType", value: goodsType.map(String.init)),
            HTTPQueryItem(name: "orderType", value: orderType),
            HTTPQueryItem(name: "operator", value: `operator`),
            HTTPQueryItem(name: "value", value: value.map { String($0) }),
        ].compactValueItems
    }
}

private extension WarehouseQueryContract {
    var queryItems: [HTTPQueryItem] {
        [
            HTTPQueryItem(name: "orgId", value: orgId.map(String.init)),
            HTTPQueryItem(name: "warehouseName", value: warehouseName),
            HTTPQueryItem(name: "goodsType", value: goodsType.map(String.init)),
            HTTPQueryItem(name: "orderType", value: orderType),
            HTTPQueryItem(name: "operator", value: `operator`),
            HTTPQueryItem(name: "value", value: value.map { String($0) }),
        ].compactValueItems
    }
}

private extension AccountAgeQueryContract {
    var queryItems: [HTTPQueryItem] {
        [
            HTTPQueryItem(name: "orgId", value: orgId.map(String.init)),
            HTTPQueryItem(name: "customerName", value: customerName),
            HTTPQueryItem(name: "orderType", value: orderType),
        ].compactValueItems + (valueArray ?? []).map { HTTPQueryItem(name: "valueArray", value: $0) }
    }
}

private extension PerformanceTypeQueryContract {
    var queryItems: [HTTPQueryItem] {
        [HTTPQueryItem(name: "indexType", value: indexType)].compactValueItems
    }
}

private extension Array where Element == HTTPQueryItem {
    var compactValueItems: [HTTPQueryItem] {
        filter { $0.value != nil }
    }
}

/// 本地预览和测试仓库，模拟模板、函数识别、图表和流式回答。
public struct PreviewAIChatRepository: AIChatRepository {
    public init() {}

    public func loadTemplate() async throws -> TemplateQuestionSetContract {
        TemplateQuestionSetContract(questions: [
            "查询本月销售额趋势",
            "按客户分析应收账款",
            "查看各组织库存吨数",
            "采购金额按月份对比",
        ])
    }

    public func loadHistoryDetail(historyId: Int) async throws -> HistoryRecordContract {
        let item = PreviewHistoryItem.item(for: historyId)
        return HistoryRecordContract(
            id: historyId,
            name: item.title,
            updateTime: ISO8601DateFormatter().string(from: .now),
            detailList: [
                HistoryDetailContract(id: historyId * 10 + 1, historyId: historyId, type: .question, contentType: .ai, content: item.question),
                HistoryDetailContract(id: historyId * 10 + 2, historyId: historyId, type: .answer, contentType: .ai, content: item.answer),
            ]
        )
    }

    public func sendFunctionMessage(text: String, historyId: Int?) async throws -> FunctionModelContract {
        if text.contains("库存") {
            return FunctionModelContract(
                historyId: historyId ?? 101,
                hasTool: true,
                name: .queryStockGroupByOrg,
                msg: "已按组织生成库存吨数对比。",
                arguments: .basic(BasicQueryContract(orgId: nil, customerName: nil, orderType: nil, operator: nil, value: nil))
            )
        }

        if text.contains("应收") {
            return FunctionModelContract(
                historyId: historyId ?? 102,
                hasTool: true,
                name: .queryArGroupByCustomer,
                msg: "已按客户生成应收账款分析。",
                arguments: .basic(BasicQueryContract(orgId: nil, customerName: nil, orderType: nil, operator: nil, value: nil))
            )
        }

        if text.contains("采购") {
            return FunctionModelContract(
                historyId: historyId ?? 103,
                hasTool: true,
                name: .queryPurchaseGroupByMonth,
                msg: "已生成采购金额月度对比。",
                arguments: .timeRange(TimeRangeQueryContract(startDate: "2026-05-01", endDate: "2026-05-31", orgId: nil, customerName: nil, goodsType: nil, orderType: nil, operator: nil, value: nil))
            )
        }

        return FunctionModelContract(
            historyId: historyId ?? 100,
            hasTool: true,
            name: .querySalesGroupByMonth,
            msg: "已生成本月销售额趋势。",
            arguments: .timeRange(TimeRangeQueryContract(startDate: "2026-05-01", endDate: "2026-05-31", orgId: nil, customerName: nil, goodsType: nil, orderType: nil, operator: nil, value: nil))
        )
    }

    public func loadChartData(name: FunctionNameContract, historyId: Int, arguments: FunctionArgumentsContract) async throws -> HistoryChartDetailContract {
        let values: [ChartCommonItemContract]
        switch name {
        case .queryStockGroupByOrg:
            values = [
                ChartCommonItemContract(bizId: "east", name: "华东", value: 186),
                ChartCommonItemContract(bizId: "south", name: "华南", value: 142),
                ChartCommonItemContract(bizId: "north", name: "华北", value: 98),
            ]
        case .queryArGroupByCustomer:
            values = [
                ChartCommonItemContract(bizId: "a", name: "远山贸易", value: 1260000),
                ChartCommonItemContract(bizId: "b", name: "青禾供应链", value: 880000),
                ChartCommonItemContract(bizId: "c", name: "星河制造", value: 520000),
            ]
        default:
            values = [
                ChartCommonItemContract(bizId: "w1", name: "第1周", value: 320000),
                ChartCommonItemContract(bizId: "w2", name: "第2周", value: 410000),
                ChartCommonItemContract(bizId: "w3", name: "第3周", value: 560000),
                ChartCommonItemContract(bizId: "w4", name: "第4周", value: 610000),
            ]
        }
        return HistoryChartDetailContract(historyDetailId: historyId * 10 + 2, funcType: name, chartCommonVoList: values)
    }

    public func sendLikeFeedback(historyDetailId: Int, like: String) async throws {}

    public func streamMessage(text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield("这是预览环境的流式回复：\(text)")
            continuation.finish()
        }
    }
}

private struct PreviewHistoryItem {
    let title: String
    let question: String
    let answer: String

    static func item(for historyId: Int) -> PreviewHistoryItem {
        switch historyId {
        case 101:
            PreviewHistoryItem(
                title: "各组织库存吨数",
                question: "查看各组织库存吨数",
                answer: "当前库存主要集中在华东、华南与华北组织，其中华东库存最高。"
            )
        case 102:
            PreviewHistoryItem(
                title: "客户应收账款分析",
                question: "按客户分析应收账款",
                answer: "远山贸易、青禾供应链与星河制造为主要应收客户，建议优先跟进高账龄客户。"
            )
        case 103:
            PreviewHistoryItem(
                title: "采购金额月度对比",
                question: "采购金额按月份对比",
                answer: "采购金额近几个月呈波动上升，第 4 周采购额最高，需要关注采购节奏。"
            )
        default:
            PreviewHistoryItem(
                title: "本月销售额趋势",
                question: "查询本月销售额趋势",
                answer: "本月销售额整体向好，华东和华南贡献最高。"
            )
        }
    }
}
