export interface LoginUiState {
  username: string
  password: string
  isPrivacyAccepted: boolean
  isLoading: boolean
  errorMessage?: string | null
  canLogin: boolean
}

export const defaultLoginUsername = 'demo'
export const defaultLoginPassword = 'demo@123'
export const maxLoginUsernameLength = 30
export const maxLoginPasswordLength = 30

export function buildLoginUiState(
  username: string,
  password: string,
  isPrivacyAccepted: boolean,
  isLoading: boolean,
  errorMessage?: string | null
): LoginUiState {
  // 输入长度限制和 canLogin 派生状态集中在应用状态层计算。
  return {
    username: limitText(username, maxLoginUsernameLength),
    password: limitText(password, maxLoginPasswordLength),
    isPrivacyAccepted: isPrivacyAccepted,
    isLoading: isLoading,
    errorMessage: errorMessage ?? null,
    canLogin: canLogin(username, password, isLoading)
  }
}

export function canLogin(username: string, password: string, isLoading: boolean): boolean {
  return hasText(username) && hasText(password) && !isLoading
}

export function validateLoginInput(state: LoginUiState): string | null {
  // 登录前做本地校验，未同意隐私政策时不请求后端。
  if (!hasText(state.username)) {
    return '请输入账号'
  }
  if (!hasText(state.password)) {
    return '请输入密码'
  }
  if (!state.isPrivacyAccepted) {
    return '请先阅读并同意《隐私政策》'
  }
  return null
}

export function limitText(value: string, maxLength: number): string {
  // 避免输入超出后端和跨端契约允许的最大长度。
  if (value.length <= maxLength) {
    return value
  }
  return value.substring(0, maxLength)
}

function hasText(value: string): boolean {
  return value.trim().length > 0
}
