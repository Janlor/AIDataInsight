export enum AppDestination {
  Login = 'login',
  AIHome = 'ai_home',
  Setting = 'setting',
  Privacy = 'privacy',
  History = 'history',
  AIChat = 'ai_chat',
}

// 所有可导航目标的稳定列表，供测试校验路由覆盖。
export const APP_DESTINATIONS: AppDestination[] = [
  AppDestination.Login,
  AppDestination.AIHome,
  AppDestination.Setting,
  AppDestination.Privacy,
  AppDestination.History,
  AppDestination.AIChat,
]
