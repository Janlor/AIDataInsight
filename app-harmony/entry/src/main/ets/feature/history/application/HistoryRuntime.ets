import { HistoryRecord } from '../../../core/model/ContractModelExports'
import { appRequester } from '../../../app/services/AppServices'
import { HistoryRepository, MockHistoryRepository, RemoteHistoryRepository } from './HistoryRepository'
import { HistoryUiState, initialHistoryUiState, makeHistoryUiState } from './HistoryState'

export class HistoryRuntimeStore {
  // 历史 runtime 缓存最近一次加载结果，抽屉重复打开时可立即渲染。
  private repository: HistoryRepository
  private records: Array<HistoryRecord> = new Array<HistoryRecord>()
  private loaded: boolean = false

  constructor(repository: HistoryRepository = new MockHistoryRepository()) {
    this.repository = repository
  }

  snapshot(): HistoryUiState {
    if (!this.loaded) {
      // 尚未加载过时返回初始空状态。
      return initialHistoryUiState()
    }
    return makeHistoryUiState(this.records, false)
  }

  async refresh(): Promise<HistoryUiState> {
    // 当前 Harmony 端只加载第一页历史，和侧边栏展示需求保持一致。
    this.records = await this.repository.loadHistoryPage(1, 20)
    this.loaded = true
    return makeHistoryUiState(this.records, false)
  }

  hasLoadedRecords(): boolean {
    return this.loaded && this.records.length > 0
  }
}

export const historyRuntimeStore = new HistoryRuntimeStore(new RemoteHistoryRepository(appRequester))
