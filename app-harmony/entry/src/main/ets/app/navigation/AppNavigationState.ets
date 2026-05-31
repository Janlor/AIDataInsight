import { AppDestination } from './AppDestination'

export interface AppNavigationState {
  current: AppDestination
  selectedHistoryId?: number
}

export function initialNavigationState(isLogin: boolean): AppNavigationState {
  // 启动时根据本地会话决定进入登录页还是 AI 首页。
  return {
    current: isLogin ? AppDestination.AIHome : AppDestination.Login,
    selectedHistoryId: undefined,
  }
}
