import {
  AIChatIntentType,
  AccountAgeQuery,
  BasicQuery,
  ChartCommonItem,
  ChartPayload,
  ChartSeries,
  ChartUnit,
  ConversationContentKind,
  ConversationMessage,
  ConversationRole,
  FeedbackState,
  FunctionArgumentKind,
  FunctionArguments,
  FunctionModel,
  FunctionName,
  HistoryChartDetail,
  HistoryContentType,
  HistoryDetailType,
  HistoryRecord,
  HistoryDetail,
  PerformanceTypeQuery,
  TemplateQuestionSet,
  TimeRangeQuery,
  WarehouseQuery,
  functionArgumentKindForName,
  functionNameFromRawValue
} from '../../../core/model/ContractModelExports'
import { CommonRequester, HttpMethod } from '../../../core/network/CommonRequester'
import { mapChartPayload, mapHistoryDetailsToMessages, normalizeTemplateQuestionSet } from '../../../contracts/mappers/ContractFixtureMappers'

// AI 聊天领域仓库，隔离远端接口、mock 数据和页面状态机。
export interface AIChatRepository {
  loadTemplate(): Promise<TemplateQuestionSet>
  loadHistoryDetail(historyId: number): Promise<HistoryRecord>
  sendFunctionMessage(text: string, historyId?: number | null): Promise<FunctionModel>
  loadChartData(name: FunctionName, historyId: number, argumentsValue: FunctionArguments): Promise<HistoryChartDetail>
  sendLikeFeedback(historyDetailId: number, like: string): Promise<void>
  streamMessage(text: string, onChunk: (chunk: string) => void): Promise<void>
}

interface RawFunctionModel {
  historyId?: number | null
  hasTool?: boolean | null
  name?: string | FunctionName | null
  msg?: string | null
  arguments?: Object | null
}

// Harmony 当前 HTTP transport 会一次性返回文本，因此 SSE 在仓库层解析为多个 chunk。
interface ParsedStreamFrame {
  chunks: Array<string>
}

interface LikeHistoryDetailRequest {
  historyDetailId: number
  like: string
}

export class RemoteAIChatRepository implements AIChatRepository {
  private requester: CommonRequester

  constructor(requester: CommonRequester) {
    this.requester = requester
  }

  async loadTemplate(): Promise<TemplateQuestionSet> {
    // 推荐问题接口在 mock 中可能返回 JSON 字符串，统一交给 mapper 归一化。
    let data = await this.requester.request<string | TemplateQuestionSet>({
      path: '/chat/template',
      method: HttpMethod.Get
    })
    return normalizeTemplateQuestionSet(data)
  }

  async loadHistoryDetail(historyId: number): Promise<HistoryRecord> {
    return this.requester.request<HistoryRecord>({
      path: `/history/detail?historyId=${historyId}`,
      method: HttpMethod.Get
    })
  }

  async sendFunctionMessage(text: string, historyId?: number | null): Promise<FunctionModel> {
    // /chat/function 会创建或续写历史，并返回图表查询需要的函数参数。
    let query = `/chat/function?question=${encodeURIComponent(text)}${historyId !== null && historyId !== undefined ? `&historyId=${historyId}` : ''}`
    let data = await this.requester.request<RawFunctionModel>({
      path: query,
      method: HttpMethod.Get
    })
    return this.normalizeFunctionModel(data)
  }

  async loadChartData(name: FunctionName, historyId: number, argumentsValue: FunctionArguments): Promise<HistoryChartDetail> {
    // 当前后端图表接口通过函数名区分路径，参数已在函数识别阶段落库。
    return this.requester.request<HistoryChartDetail>({
      path: `/chart/${name}?historyId=${historyId}`,
      method: HttpMethod.Get
    })
  }

  async sendLikeFeedback(historyDetailId: number, like: string): Promise<void> {
    let body: LikeHistoryDetailRequest = {
      historyDetailId: historyDetailId,
      like: like
    }
    await this.requester.requestEmpty({
      path: '/history/like',
      method: HttpMethod.Post,
      body: body
    })
  }

  async streamMessage(text: string, onChunk: (chunk: string) => void): Promise<void> {
    // 文本流是非工具回答的兜底路径，使用 requestRaw 跳过响应信封解析。
    let headers = new Map<string, string>()
    headers.set('Accept', 'text/event-stream')
    headers.set('Cache-Control', 'no-cache')
    let responseText = await this.requester.requestRaw({
      path: `/stream?question=${encodeURIComponent(text)}`,
      method: HttpMethod.Get,
      headers: headers
    })
    let chunks = this.parseStreamChunks(responseText)
    for (let index = 0; index < chunks.length; index++) {
      // 模拟真实流式体验，避免一次性返回时 UI 没有增量变化。
      await this.delay(90)
      onChunk(chunks[index])
    }
  }

  private normalizeFunctionModel(model: RawFunctionModel): FunctionModel {
    // name 可能是后端原始字符串，进入应用层前转换为强类型枚举。
    let name = typeof model.name === 'string' ? functionNameFromRawValue(model.name) : model.name ?? null
    return {
      historyId: model.historyId ?? null,
      hasTool: model.hasTool ?? null,
      name: name,
      msg: model.msg ?? null,
      arguments: this.normalizeFunctionArguments(name, model.arguments ?? null)
    }
  }

  private normalizeFunctionArguments(name: FunctionName | null, rawArguments: Object | null): FunctionArguments | null {
    if (name === null || rawArguments === null) {
      return null
    }
    let kind = functionArgumentKindForName(name)
    // arguments 的真实结构依赖函数名，按 kind 分发到具体参数字段。
    if (kind === FunctionArgumentKind.TimeRange) {
      return {
        kind: kind,
        timeRange: rawArguments as TimeRangeQuery
      }
    }
    if (kind === FunctionArgumentKind.Warehouse) {
      return {
        kind: kind,
        warehouse: rawArguments as WarehouseQuery
      }
    }
    if (kind === FunctionArgumentKind.AccountAge) {
      return {
        kind: kind,
        accountAge: rawArguments as AccountAgeQuery
      }
    }
    if (kind === FunctionArgumentKind.PerformanceType) {
      return {
        kind: kind,
        performanceType: rawArguments as PerformanceTypeQuery
      }
    }
    return {
      kind: kind,
      basic: rawArguments as BasicQuery
    }
  }

  private parseStreamChunks(responseText: string): Array<string> {
    // 兼容标准 SSE data 行，以及测试中直接返回纯文本的情况。
    let chunks = new Array<string>()
    let lines = responseText.split('\n')
    for (let index = 0; index < lines.length; index++) {
      let line = lines[index].trim()
      if (line.length === 0 || !line.startsWith('data:')) {
        continue
      }
      let payload = line.substring(5).trim()
      if (payload.length === 0 || payload === '[DONE]') {
        continue
      }
      this.appendStreamPayload(chunks, payload)
    }
    if (chunks.length === 0 && responseText.trim().length > 0) {
      this.appendStreamPayload(chunks, responseText.trim())
    }
    return chunks
  }

  private consumeStreamBuffer(buffer: string, isFinal: boolean, onChunk: (chunk: string) => void): string {
    let remaining = buffer
    let lineBreakIndex = remaining.indexOf('\n')
    while (lineBreakIndex >= 0) {
      let line = remaining.substring(0, lineBreakIndex).trim()
      this.emitStreamLine(line, onChunk)
      remaining = remaining.substring(lineBreakIndex + 1)
      lineBreakIndex = remaining.indexOf('\n')
    }
    if (isFinal && remaining.trim().length > 0) {
      this.emitStreamLine(remaining.trim(), onChunk)
      return ''
    }
    return remaining
  }

  private emitStreamLine(line: string, onChunk: (chunk: string) => void): void {
    if (line.length === 0 || !line.startsWith('data:')) {
      return
    }
    let payload = line.substring(5).trim()
    if (payload.length === 0 || payload === '[DONE]') {
      return
    }
    let chunks = new Array<string>()
    this.appendStreamPayload(chunks, payload)
    for (let index = 0; index < chunks.length; index++) {
      onChunk(chunks[index])
    }
  }

  private appendStreamPayload(chunks: Array<string>, payload: string): void {
    try {
      // 部分 mock 会把多个 chunk 包成 JSON 数组帧。
      let parsed = JSON.parse(payload) as ParsedStreamFrame
      if (parsed.chunks !== undefined && parsed.chunks.length > 0) {
        for (let index = 0; index < parsed.chunks.length; index++) {
          chunks.push(parsed.chunks[index])
        }
        return
      }
    } catch (error) {
      // 不是 JSON 帧时按普通文本 chunk 处理。
    }
    chunks.push(payload)
  }

  private delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, milliseconds)
    })
  }
}

export enum SendFunctionResultKind {
  Intent = 'intent',
  ChartRequest = 'chartRequest',
  Failure = 'failure'
}

export interface SendFunctionResult {
  kind: SendFunctionResultKind
  text?: string | null
  intentType?: AIChatIntentType | null
  name?: FunctionName | null
  historyId?: number | null
  argumentsValue?: FunctionArguments | null
  message?: string | null
}

export enum LoadChartResultKind {
  Chart = 'chart',
  Failure = 'failure'
}

export interface LoadChartResult {
  kind: LoadChartResultKind
  payload?: ChartPayload | null
  historyDetailId?: number | null
  message?: string | null
}

export class MockAIChatRepository implements AIChatRepository {
  // 本地 mock 记录反馈状态，方便测试点赞/点踩回显。
  private liked: Map<number, string> = new Map<number, string>()

  async loadTemplate(): Promise<TemplateQuestionSet> {
    return {
      questions: [
        '今年第三季度销售额大于2亿的公司有哪些？',
        '查看仓库中煤炭库存大于5万吨的公司。',
        '列出公司FHJK应收余额超过5000万的客户。',
        '钢材存货金额余额最多的公司？',
        '查看各公司账龄超过180天的金额。'
      ]
    }
  }

  async loadHistoryDetail(historyId: number): Promise<HistoryRecord> {
    if (historyId === 1002) {
      return {
        id: historyId,
        name: '仓库库存分析',
        createTime: '2026-05-01 14:20:00',
        updateTime: '2026-05-01 14:21:00',
        detailList: [
          {
            id: 3001,
            historyId: historyId,
            type: HistoryDetailType.Question,
            contentType: HistoryContentType.Ai,
            content: '查询库存分布',
            isLike: null
          },
          {
            id: 3002,
            historyId: historyId,
            type: HistoryDetailType.Answer,
            contentType: HistoryContentType.Ai,
            content: '{"historyId":1002,"hasTool":false,"name":null,"msg":"当前库存主要集中在一号仓和二号仓，可继续按仓库细看。","arguments":null}',
            isLike: null
          }
        ]
      }
    }

    return {
      id: historyId,
      name: '查看一月销售额',
      createTime: '2026-01-31 10:00:00',
      updateTime: '2026-01-31 10:01:00',
      detailList: [
        {
          id: 2001,
          historyId: historyId,
          type: HistoryDetailType.Question,
          contentType: HistoryContentType.Ai,
          content: '查看一月销售额',
          isLike: null
        },
        {
          id: 2002,
          historyId: historyId,
          type: HistoryDetailType.Answer,
          contentType: HistoryContentType.Chart,
          content: '{"funcType":"querySalesGroupByMonth","chartCommonVoList":[{"bizId":"2026-01","name":"2026-01","value":128800.5}],"accountAgeGroupVoList":null}',
          isLike: this.liked.get(2002) ?? '1'
        }
      ]
    }
  }

  async sendFunctionMessage(text: string, historyId?: number | null): Promise<FunctionModel> {
    if (text.indexOf('fallback') >= 0 || text.indexOf('测试降级') >= 0) {
      // 构造参数类型不匹配场景，用于验证图表失败兜底。
      return {
        historyId: historyId ?? 1001,
        hasTool: true,
        name: FunctionName.QuerySalesGroupByMonth,
        msg: null,
        arguments: {
          kind: FunctionArgumentKind.Basic,
          basic: {}
        }
      }
    }

    if (text.indexOf('销售') >= 0 && text.indexOf('本月') < 0 && text.indexOf('一月') < 0) {
      // 时间类问题缺少时间范围时，返回 intent 引导用户补充。
      return {
        historyId: historyId ?? null,
        hasTool: true,
        name: FunctionName.QuerySalesGroupByMonth,
        msg: '请选择查询时间范围',
        arguments: {
          kind: FunctionArgumentKind.TimeRange,
          timeRange: {
            startDate: null,
            endDate: null
          }
        }
      }
    }

    if (text.indexOf('图表') >= 0 || text.indexOf('销售') >= 0 || text.indexOf('本月') >= 0) {
      return {
        historyId: historyId ?? 1001,
        hasTool: true,
        name: FunctionName.QuerySalesGroupByMonth,
        msg: null,
        arguments: {
          kind: FunctionArgumentKind.TimeRange,
          timeRange: {
            startDate: '2026-05-01',
            endDate: '2026-05-31'
          }
        }
      }
    }

    return {
      historyId: historyId ?? null,
      hasTool: false,
      name: null,
      msg: null,
      arguments: null
    }
  }

  async loadChartData(name: FunctionName, historyId: number, argumentsValue: FunctionArguments): Promise<HistoryChartDetail> {
    if (argumentsValue.kind !== FunctionArgumentKind.TimeRange) {
      return {
        funcType: name,
        chartCommonVoList: new Array<ChartCommonItem>(),
        accountAgeGroupVoList: null
      }
    }

    return {
      funcType: name,
      chartCommonVoList: [
        { bizId: '2026-05', name: '2026-05', value: 128000.0 },
        { bizId: '2026-04', name: '2026-04', value: 96000.0 }
      ],
      accountAgeGroupVoList: null
    }
  }

  async sendLikeFeedback(historyDetailId: number, like: string): Promise<void> {
    this.liked.set(historyDetailId, like)
  }

  async streamMessage(text: string, onChunk: (chunk: string) => void): Promise<void> {
    let chunks = [
      '您好，',
      '这是基于 mock 数据生成的经营分析结果。',
      ' 当前链路已支持流式增量展示。'
    ]
    for (let index = 0; index < chunks.length; index++) {
      await this.delay(160)
      onChunk(chunks[index])
    }
  }

  private delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, milliseconds)
    })
  }
}

export class LoadTemplateUseCase {
  private repository: AIChatRepository

  constructor(repository: AIChatRepository) {
    this.repository = repository
  }

  async execute(): Promise<Array<string>> {
    // 页面只需要问题数组，仓库负责处理接口兼容格式。
    let template = await this.repository.loadTemplate()
    return template.questions
  }
}

export class LoadHistoryDetailUseCase {
  private repository: AIChatRepository

  constructor(repository: AIChatRepository) {
    this.repository = repository
  }

  async execute(historyId: number): Promise<Array<ConversationMessage>> {
    // 历史详情明细在 use case 层转换成统一聊天消息。
    let record = await this.repository.loadHistoryDetail(historyId)
    return mapHistoryDetailsToMessages(record.detailList ?? new Array<HistoryDetail>())
  }
}

export class SendFunctionMessageUseCase {
  private repository: AIChatRepository

  constructor(repository: AIChatRepository) {
    this.repository = repository
  }

  async execute(text: string, historyId?: number | null): Promise<SendFunctionResult> {
    // 发送问题后先做函数识别，再决定下一步是补参数、拉图表还是失败兜底。
    let model = await this.repository.sendFunctionMessage(text, historyId)
    if (model.hasTool !== true) {
      return { kind: SendFunctionResultKind.Failure, message: model.msg ?? null }
    }
    if (model.name === null || model.name === undefined || model.arguments === null || model.arguments === undefined) {
      return { kind: SendFunctionResultKind.Failure, message: model.msg ?? null }
    }
    if (model.arguments.kind === FunctionArgumentKind.TimeRange) {
      let query = model.arguments.timeRange
      if (query === null || query === undefined || query.startDate === null || query.startDate === undefined) {
        // 时间范围缺失时不请求图表，直接让页面展示补充提示。
        return {
          kind: SendFunctionResultKind.Intent,
          text: '请选择查询时间范围',
          intentType: AIChatIntentType.Time
        }
      }
    }
    if (model.arguments.kind === FunctionArgumentKind.PerformanceType) {
      // 指标类型需要用户进一步选择。
      return {
        kind: SendFunctionResultKind.Intent,
        text: '请选择分析指标',
        intentType: AIChatIntentType.Index
      }
    }
    if (model.historyId === null || model.historyId === undefined) {
      return { kind: SendFunctionResultKind.Failure, message: model.msg ?? null }
    }
    return {
      kind: SendFunctionResultKind.ChartRequest,
      name: model.name,
      historyId: model.historyId,
      argumentsValue: model.arguments
    }
  }
}

export class LoadChartDataUseCase {
  private repository: AIChatRepository

  constructor(repository: AIChatRepository) {
    this.repository = repository
  }

  async execute(name: FunctionName, historyId: number, argumentsValue: FunctionArguments): Promise<LoadChartResult> {
    // 图表详情统一映射为 ChartPayload，空图表返回 Failure 供 UI 展示兜底文案。
    let detail = await this.repository.loadChartData(name, historyId, argumentsValue)
    let payload = mapChartPayload(detail)
    if (payload.series.length === 0) {
      return { kind: LoadChartResultKind.Failure, message: payload.emptyMessage ?? null }
    }
    return { kind: LoadChartResultKind.Chart, payload: payload, historyDetailId: detail.historyDetailId ?? null }
  }
}

export class SendLikeFeedbackUseCase {
  private repository: AIChatRepository

  constructor(repository: AIChatRepository) {
    this.repository = repository
  }

  async execute(historyDetailId: number, like: string): Promise<boolean> {
    // 成功返回 true，页面层据此保留乐观更新结果。
    await this.repository.sendLikeFeedback(historyDetailId, like)
    return true
  }
}

export class StreamAIResponseUseCase {
  private repository: AIChatRepository

  constructor(repository: AIChatRepository) {
    this.repository = repository
  }

  async execute(text: string, onChunk: (chunk: string) => void): Promise<void> {
    // 非工具回答走流式文本，onChunk 逐段更新最后一条助手消息。
    await this.repository.streamMessage(text, onChunk)
  }
}

export function makeFallbackChartPayload(functionName?: FunctionName | null): ChartPayload {
  // 图表加载失败时构造空 payload，让页面复用图表空态渲染。
  return {
    functionName: functionName ?? null,
    unit: ChartUnit.Currency,
    series: new Array<ChartSeries>(),
    emptyMessage: '数据分析还在测试阶段，很快就能上线，敬请期待！'
  }
}
