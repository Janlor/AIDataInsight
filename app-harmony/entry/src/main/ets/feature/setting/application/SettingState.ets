import { AccountSession, AccountUser, SettingSnapshot } from '../../../core/model/ContractModelExports'

export function buildSettingSnapshot(session: AccountSession, user: AccountUser | null = null): SettingSnapshot {
  // 设置页优先展示远端用户资料，缺失时回退到会话中的 username。
  return {
    accountInfo: {
      nickname: user?.nickname ?? null,
      username: user?.username ?? session.username ?? null,
      phone: user?.phone ?? null
    },
    capability: {
      canUpdatePassword: false,
      canOpenPrivacy: true,
      canLogout: true
    },
    appVersion: '1.0.0'
  }
}

export function displaySettingText(value?: string | null): string {
  // 契约空值统一显示为“未设置”。
  if (value === null || value === undefined || value.length === 0) {
    return '未设置'
  }
  return value
}
