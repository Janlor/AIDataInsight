import { AccountAuthService } from '../../core/account/AccountAuthService'
import { common } from '@kit.AbilityKit'
import { PreferencesAccountSessionStore } from '../../core/account/AccountSessionStore'
import { PreferencesAccountUserStore } from '../../core/account/AccountUserStore'
import { CommonRequester } from '../../core/network/CommonRequester'
import { HarmonyHttpTransport } from '../../core/network/HarmonyHttpTransport'

// 应用级单例依赖，页面和 Feature 通过这里共享账号、网络和本地存储。
export const appSessionStore = new PreferencesAccountSessionStore()
export const appUserStore = new PreferencesAccountUserStore()
export const appHttpTransport = new HarmonyHttpTransport()
export const appRequester = new CommonRequester(appHttpTransport)
export const accountAuthService = new AccountAuthService(appRequester, appSessionStore, appUserStore)

export function configureAppServices(context: common.UIAbilityContext): void {
  // Preferences 依赖 UIAbilityContext，必须在 Ability onCreate 后配置。
  appSessionStore.configure(context)
  appUserStore.configure(context)
}
