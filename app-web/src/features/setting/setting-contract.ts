import {
  settingInitialUiState,
  type AccountSession,
  type AccountUser,
  type SettingRow,
  type SettingUiState,
} from '@/contracts/generated/models';

const contractState = settingInitialUiState;
const unsetText = '未设置';

export function buildSettingStateFromContract({
  session,
  user,
}: {
  session: AccountSession;
  user: AccountUser | null;
}): SettingUiState {
  // generated contract 提供静态结构；账号相关行在运行时用当前会话和用户资料填充。
  return {
    ...contractState,
    sections: contractState.sections.map((section) => ({
      ...section,
      rows: section.rows.map((row) => hydrateAccountRow(row, session, user)),
    })),
    logoutDialog: {
      ...contractState.logoutDialog,
      visible: false,
    },
  };
}

export function getDisplayName(session: AccountSession, user: AccountUser | null, fallback = '已登录用户') {
  // 展示名优先级和移动端保持一致：昵称 > 用户名 > 会话用户名 > 兜底文案。
  return user?.nickname ?? user?.username ?? session.username ?? fallback;
}

export function getInitials(name: string) {
  // 英文多词取前两个词首字母，中文或紧凑名称取前两个字符。
  const parts = name
    .trim()
    .split(/\s+/)
    .filter(Boolean);

  if (parts.length >= 2) {
    return `${parts[0][0] ?? ''}${parts[1][0] ?? ''}`.toUpperCase();
  }

  return name.trim().slice(0, 2).toUpperCase() || 'AI';
}

function hydrateAccountRow(row: SettingRow, session: AccountSession, user: AccountUser | null): SettingRow {
  if (row.kind === 'nickname') {
    return { ...row, detail: user?.nickname ?? unsetText };
  }

  if (row.kind === 'username') {
    return { ...row, detail: user?.username ?? session.username ?? unsetText };
  }

  if (row.kind === 'phone') {
    return { ...row, detail: user?.phone ?? unsetText };
  }

  return row;
}
