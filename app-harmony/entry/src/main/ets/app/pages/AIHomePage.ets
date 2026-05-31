import { AIChatPage } from '../../feature/ai_chat/pages/AIChatPage'
import { HistoryPage } from '../../feature/history/pages/HistoryPage'
import { AppColors, AppTypography } from '../../core/ui/theme/AppTheme'

@Component
export struct AIHomePage {
  @Prop @Watch('onOpenHistoryVersionChanged') openHistoryVersion: number = 0

  onOpenSettings: () => void = () => {}

  @State isHistoryMounted: boolean = false
  @State drawerProgress: number = 0
  @State dragStartProgress: number = 0
  @State historyRefreshVersion: number = 0
  @State selectedHistoryId: number | null = null
  @State conversationVersion: number = 0
  @State pageWidth: number = 0
  @State pageHeight: number = 0

  aboutToAppear() {
    if (this.openHistoryVersion > 0) {
      // 外部传入版本号时，进入首页后自动打开历史抽屉。
      this.openHistoryPanel()
    }
  }

  private onOpenHistoryVersionChanged(): void {
    if (this.openHistoryVersion > 0) {
      // 设置页返回后通过版本号触发历史抽屉刷新和打开。
      this.openHistoryPanel()
    }
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Image($r('app.media.background_vc'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Column() {
        this.navigationBar()

        AIChatPage({
          selectedHistoryId: this.selectedHistoryId,
          conversationVersion: this.conversationVersion,
          drawBackground: false
        })
          .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 44, bottom: 18 })
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal, distance: 8 })
          .onActionStart((event: GestureEvent) => {
            this.dragStartProgress = this.drawerProgress
          })
          .onActionUpdate((event: GestureEvent) => {
            // 主内容区域也接收横向拖动，支持从页面内滑出历史抽屉。
            this.handleDrawerDrag(event as PanGestureEvent)
          })
          .onActionEnd((event: GestureEvent) => {
            this.settleDrawer(event as PanGestureEvent)
          })
      )

      if (this.isHistoryMounted) {
        Row()
          .width('100%')
          .height('100%')
          .opacity(this.drawerProgress)
          .backgroundColor('#66000000')
          .hitTestBehavior(this.drawerProgress > 0 ? HitTestMode.Default : HitTestMode.None)
          .onClick(() => {
            this.closeHistoryPanel()
          })

        Row() {
          HistoryPage({
            refreshVersion: this.historyRefreshVersion,
            onClose: () => {
              this.closeHistoryPanel()
            },
            onOpenSettings: () => {
              this.closeHistoryPanel()
              this.onOpenSettings()
            },
            onSelectHistory: (historyId: number) => {
              this.selectedHistoryId = historyId
              this.closeHistoryPanel()
            }
          })
        }
        .width(this.historyPanelWidth())
        .height('100%')
        .backgroundColor('#F6FAFF')
        .shadow({ radius: 18, color: '#33000000', offsetX: 4, offsetY: 0 })
        .translate({ x: -this.historyPanelWidth() * (1 - this.drawerProgress), y: 0, z: 0 })
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal, distance: 6 })
            .onActionStart((event: GestureEvent) => {
              this.dragStartProgress = this.drawerProgress
            })
            .onActionUpdate((event: GestureEvent) => {
              this.handleDrawerDrag(event as PanGestureEvent)
            })
            .onActionEnd((event: GestureEvent) => {
              this.settleDrawer(event as PanGestureEvent)
            })
        )
      }

      if (this.drawerProgress === 0) {
        // 抽屉关闭时保留左侧热区，便于从屏幕边缘滑出历史面板。
        Row()
          .width(24)
          .height('100%')
          .hitTestBehavior(HitTestMode.Transparent)
          .gesture(
            PanGesture({ direction: PanDirection.Horizontal, distance: 8 })
              .onActionStart((event: GestureEvent) => {
                this.dragStartProgress = this.drawerProgress
                this.ensureHistoryMounted()
              })
              .onActionUpdate((event: GestureEvent) => {
                this.handleDrawerDrag(event as PanGestureEvent)
              })
              .onActionEnd((event: GestureEvent) => {
                this.settleDrawer(event as PanGestureEvent)
              })
          )
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.pageWidth = this.areaNumber(newArea.width)
      this.pageHeight = this.areaNumber(newArea.height)
    })
  }

  @Builder
  private navigationBar() {
    Row() {
      Text('历史')
        .fontSize(AppTypography.body)
        .fontColor(AppColors.accent)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .onClick(() => {
          this.openHistoryPanel()
        })

      Column() {
        Text('AI数据分析助手')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.textPrimary)
        Text('经营数据分析')
          .fontSize(12)
          .fontColor(AppColors.textSecondary)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Center)
      .layoutWeight(1)

      Text('新会话')
        .fontSize(AppTypography.body)
        .fontColor(AppColors.accent)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .onClick(() => {
          this.selectedHistoryId = null
          // conversationVersion 变化会让 AIChatPage 重置为新会话。
          this.conversationVersion += 1
        })
    }
    .width('100%')
    .height(56)
    .alignItems(VerticalAlign.Center)
  }

  private openHistoryPanel(): void {
    this.ensureHistoryMounted()
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.drawerProgress = 1
    })
  }

  private closeHistoryPanel(): void {
    this.getUIContext().animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
      this.drawerProgress = 0
    })
  }

  private ensureHistoryMounted(): void {
    if (!this.isHistoryMounted) {
      this.isHistoryMounted = true
    }
    if (this.drawerProgress === 0) {
      // 每次从关闭态打开抽屉时刷新历史列表。
      this.historyRefreshVersion += 1
    }
  }

  private handleDrawerDrag(event: PanGestureEvent): void {
    this.ensureHistoryMounted()
    let panelWidth = this.historyPanelWidth()
    if (panelWidth <= 0) {
      return
    }
    let nextProgress = this.dragStartProgress + event.offsetX / panelWidth
    this.drawerProgress = this.clampProgress(nextProgress)
  }

  private settleDrawer(event: PanGestureEvent): void {
    // 根据速度和当前位置决定最终打开或关闭，手感接近系统抽屉。
    let shouldOpen = event.velocityX > 500 || (event.velocityX > -500 && this.drawerProgress >= 0.5)
    this.getUIContext().animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
      this.drawerProgress = shouldOpen ? 1 : 0
    })
  }

  private historyPanelWidth(): number {
    let width = this.pageWidth > 0 ? this.pageWidth : 390
    if (width >= 600) {
      // 宽屏固定侧栏宽度，窄屏使用 86% 宽度。
      return 320
    }
    return Math.min(360, Math.round(width * 0.86))
  }

  private clampProgress(value: number): number {
    if (value < 0) {
      return 0
    }
    if (value > 1) {
      return 1
    }
    return value
  }

  private areaNumber(value: number | string | Resource): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value === 'string') {
      let parsed = Number(value)
      return isNaN(parsed) ? 0 : parsed
    }
    return 0
  }
}
