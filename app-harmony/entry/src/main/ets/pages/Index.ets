import { AppDestination } from '../app/navigation/AppDestination'
import { accountAuthService } from '../app/services/AppServices'
import { AIHomePage } from '../app/pages/AIHomePage'
import { AIDataInsightGradientBackground } from '../core/ui/components/AIDataInsightGradientBackground'
import { AppColors, AppTypography } from '../core/ui/theme/AppTheme'
import { LoginPage } from '../feature/login/pages/LoginPage'
import { PrivacyPage } from '../feature/privacy/pages/PrivacyPage'
import { SettingPage } from '../feature/setting/pages/SettingPage'

@Entry
@Component
struct Index {
  @State current: AppDestination = AppDestination.Login
  @State privacyBackDestination: AppDestination = AppDestination.Login
  @State isResolvingSession: boolean = true
  @State historyOpenRequestVersion: number = 0

  aboutToAppear() {
    // 页面出现时先解析本地登录态，再决定初始页面。
    this.resolveInitialDestination()
  }

  build() {
    Stack() {
      AIDataInsightGradientBackground()

      if (this.isResolvingSession) {
        // 会话恢复期间展示轻量启动态，避免登录页和首页闪烁。
        Column() {
          Text('AIDataInsight')
            .fontSize(AppTypography.title)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.textPrimary)
          Text('正在检查登录状态')
            .fontSize(AppTypography.footnote)
            .fontColor(AppColors.textSecondary)
            .margin({ top: 8 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.current === AppDestination.AIHome) {
        AIHomePage({
          openHistoryVersion: this.historyOpenRequestVersion,
          onOpenSettings: () => {
            this.current = AppDestination.Setting
          }
        })
      } else if (this.current === AppDestination.Privacy) {
        PrivacyPage({
          onBack: () => {
            this.current = this.privacyBackDestination
          }
        })
      } else if (this.current === AppDestination.Setting) {
        SettingPage({
          onBack: () => {
            // 从设置页返回首页时触发一次历史面板刷新请求。
            this.historyOpenRequestVersion += 1
            this.current = AppDestination.AIHome
          },
          onOpenPrivacy: () => {
            this.privacyBackDestination = AppDestination.Setting
            this.current = AppDestination.Privacy
          },
          onLogoutSucceeded: () => {
            this.historyOpenRequestVersion = 0
            this.current = AppDestination.Login
          }
        })
      } else {
        LoginPage({
          onLoginSucceeded: () => {
            this.historyOpenRequestVersion = 0
            this.current = AppDestination.AIHome
          },
          onOpenPrivacy: () => {
            this.privacyBackDestination = AppDestination.Login
            this.current = AppDestination.Privacy
          }
        })
      }
    }
    .height('100%')
    .width('100%')
  }

  private async resolveInitialDestination(): Promise<void> {
    // 当前仅依赖本地 accessToken 判断是否可自动进入主界面。
    let canAutoLogin = await accountAuthService.canAutoLogin()
    this.current = canAutoLogin ? AppDestination.AIHome : AppDestination.Login
    this.isResolvingSession = false
  }
}
