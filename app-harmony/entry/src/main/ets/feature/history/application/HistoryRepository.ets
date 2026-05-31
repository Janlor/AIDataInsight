import { HistoryRecord, RecordPage } from '../../../core/model/ContractModelExports'
import { CommonRequester, HttpMethod } from '../../../core/network/CommonRequester'

// 历史仓库抽象，页面只关心会话列表，不关心远端分页信封。
export interface HistoryRepository {
  loadHistoryPage(currentPage: number, pageSize: number): Promise<Array<HistoryRecord>>
}

export class RemoteHistoryRepository implements HistoryRepository {
  private requester: CommonRequester

  constructor(requester: CommonRequester) {
    this.requester = requester
  }

  async loadHistoryPage(currentPage: number, pageSize: number): Promise<Array<HistoryRecord>> {
    // 当前页面只使用 records；分页元信息暂不进入 UI 状态。
    let page = await this.requester.request<RecordPage>({
      path: `/history/page?currentPage=${currentPage}&pageSize=${pageSize}`,
      method: HttpMethod.Get
    })
    return page.records ?? new Array<HistoryRecord>()
  }
}

export class MockHistoryRepository implements HistoryRepository {
  async loadHistoryPage(currentPage: number, pageSize: number): Promise<Array<HistoryRecord>> {
    // Mock 忽略分页参数，返回稳定样例数据用于预览和测试。
    return mockHistoryRecords()
  }
}

export function mockHistoryRecords(): Array<HistoryRecord> {
  let today = todayString()
  let thisMonth = `${today.substring(0, 8)}01`
  return [
    {
      id: 1001,
      name: '查看一月销售额',
      createTime: `${today} 09:15:00`,
      updateTime: `${today} 09:16:00`,
      detailList: null
    },
    {
      id: 1002,
      name: '仓库库存分析',
      createTime: `${thisMonth} 14:20:00`,
      updateTime: `${thisMonth} 14:21:00`,
      detailList: null
    },
    {
      id: 1003,
      name: '应收账款排行',
      createTime: '2026-01-31 10:00:00',
      updateTime: '2026-01-31 10:01:00',
      detailList: null
    }
  ]
}

function todayString(): string {
  // 动态生成今天和本月数据，保证分组测试不过期。
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
