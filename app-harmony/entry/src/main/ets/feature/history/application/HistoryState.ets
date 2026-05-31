import { HistoryRecord } from '../../../core/model/ContractModelExports'

export interface HistoryItemUiModel {
  id: string
  title: string
  displayTime: string
}

export interface HistorySectionUiModel {
  title: string
  items: Array<HistoryItemUiModel>
}

export interface HistoryUiState {
  title: string
  sections: Array<HistorySectionUiModel>
  isLoading: boolean
  isRefreshing: boolean
  isDeleting: boolean
  hasMore: boolean
  errorMessage?: string | null
}

export function initialHistoryUiState(): HistoryUiState {
  return {
    title: '历史会话',
    sections: new Array<HistorySectionUiModel>(),
    isLoading: false,
    isRefreshing: false,
    isDeleting: false,
    hasMore: false,
    errorMessage: null
  }
}

export function buildHistorySections(records: Array<HistoryRecord>): Array<HistorySectionUiModel> {
  // 历史列表按更新时间归入“今天 / 本月 / 其它”，并保持固定展示顺序。
  let groups = new Map<string, Array<HistoryRecord>>()
  for (let index = 0; index < records.length; index++) {
    let record = records[index]
    let title = sectionTitleFor(record.updateTime ?? record.createTime)
    if (!groups.has(title)) {
      groups.set(title, new Array<HistoryRecord>())
    }
    groups.get(title)?.push(record)
  }

  let sections = new Array<HistorySectionUiModel>()
  appendSection(sections, groups, '今天')
  appendSection(sections, groups, '本月')
  appendSection(sections, groups, '其它')
  return sections
}

export function makeHistoryUiState(records: Array<HistoryRecord>, isRefreshing: boolean = false): HistoryUiState {
  return {
    title: '历史会话',
    sections: buildHistorySections(records),
    isLoading: false,
    isRefreshing: isRefreshing,
    isDeleting: false,
    hasMore: false,
    errorMessage: null
  }
}

function appendSection(
  sections: Array<HistorySectionUiModel>,
  groups: Map<string, Array<HistoryRecord>>,
  title: string
): void {
  let records = groups.get(title)
  if (records === undefined || records.length === 0) {
    return
  }

  // 空分区不展示，避免侧边栏出现无内容标题。
  let items = new Array<HistoryItemUiModel>()
  for (let index = 0; index < records.length; index++) {
    let record = records[index]
    items.push({
      id: `${record.id ?? 0}`,
      title: displayTitle(record.name),
      displayTime: displayTime(record, title)
    })
  }
  sections.push({ title: title, items: items })
}

function sectionTitleFor(value?: string | null): string {
  // 后端时间格式为 yyyy-MM-dd HH:mm:ss，取前 10 位即可判断日期归属。
  if (value === null || value === undefined || value.length < 10) {
    return '其它'
  }

  let date = value.substring(0, 10)
  let today = todayString()
  if (date === today) {
    return '今天'
  }
  if (date.substring(0, 7) === today.substring(0, 7)) {
    return '本月'
  }
  return '其它'
}

function displayTime(record: HistoryRecord, sectionTitle: string): string {
  // 不同分区展示不同粒度时间，减少列表信息噪音。
  let source = record.updateTime ?? record.createTime ?? ''
  if (sectionTitle === '今天' && source.length >= 16) {
    return source.substring(11, 16)
  }
  if (sectionTitle === '本月' && source.length >= 10) {
    return source.substring(5, 10)
  }
  if (source.length >= 10) {
    return source.substring(0, 10)
  }
  return ''
}

function displayTitle(value?: string | null): string {
  if (value === null || value === undefined || value.length === 0) {
    return '未命名会话'
  }
  return value
}

function todayString(): string {
  let now = new Date()
  let month = twoDigits(now.getMonth() + 1)
  let day = twoDigits(now.getDate())
  return `${now.getFullYear()}-${month}-${day}`
}

function twoDigits(value: number): string {
  if (value < 10) {
    return `0${value}`
  }
  return `${value}`
}
