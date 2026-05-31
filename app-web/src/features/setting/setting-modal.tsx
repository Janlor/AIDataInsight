'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { ChevronRight, Loader2, X } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import type { SettingRow } from '@/contracts/generated/models';
import { useAccountStore } from '@/data/account/session-store';
import { useI18n } from '@/i18n/use-i18n';
import { buildSettingStateFromContract } from './setting-contract';

export function SettingModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const router = useRouter();
  const { locale, setLocale, t } = useI18n();
  const session = useAccountStore((state) => state.session);
  const user = useAccountStore((state) => state.user);
  const logout = useAccountStore((state) => state.logout);
  const loadUserInfo = useAccountStore((state) => state.loadUserInfo);
  const [isConfirmingLogout, setConfirmingLogout] = useState(false);
  const [isChoosingLanguage, setChoosingLanguage] = useState(false);
  const [isLoggingOut, setLoggingOut] = useState(false);
  const settingState = useMemo(
    () => buildSettingStateFromContract({ session, user }),
    [session, user],
  );

  useEffect(() => {
    if (open && session.isLogin) {
      // 打开设置时刷新用户资料，先展示缓存，远端失败不阻断弹窗。
      void loadUserInfo().catch(() => undefined);
    }
  }, [loadUserInfo, open, session.isLogin]);

  if (!open) {
    return null;
  }

  async function confirmLogout() {
    setLoggingOut(true);
    await logout().finally(() => {
      // 无论后端 logout 是否成功，本地都清理会话并回到登录页。
      setLoggingOut(false);
      setConfirmingLogout(false);
      onClose();
      router.replace('/login');
    });
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/35 p-0 sm:items-center sm:p-6">
      <div
        aria-labelledby="setting-modal-title"
        aria-modal="true"
        className="max-h-[88vh] w-full overflow-hidden rounded-t-lg border border-separator bg-surface-primary shadow-xl sm:max-w-lg sm:rounded-lg"
        role="dialog"
      >
        <header className="flex h-14 items-center justify-between border-b border-separator px-4">
          <h2 id="setting-modal-title" className="text-base font-semibold text-label-primary">
            {t.setting.title}
          </h2>
          <button
            aria-label={t.setting.close}
            className="flex h-9 w-9 items-center justify-center rounded-control text-label-secondary transition hover:bg-surface-secondary hover:text-label-primary"
            type="button"
            onClick={onClose}
          >
            <X aria-hidden="true" size={18} />
          </button>
        </header>

        <div className="max-h-[calc(88vh-3.5rem)] overflow-y-auto bg-surface-secondary px-4 py-4">
          <div className="space-y-4">
            {settingState.sections.map((section) => (
              <section key={section.kind}>
                {section.title ? (
                  <h3 className="mb-2 px-1 text-xs font-semibold text-label-tertiary">
                    {t.setting.sections[section.kind]}
                  </h3>
                ) : null}
                <div className="overflow-hidden rounded-lg border border-separator bg-surface-primary">
                  {section.rows.map((row) => (
                    <SettingRowItem
                      key={row.kind}
                      row={row}
                      disabled={isLoggingOut}
                      onClose={onClose}
                      onConfirmLogout={() => setConfirmingLogout(true)}
                    />
                  ))}
                  {section.kind === 'about' ? (
                    <>
                      {/* 语言切换是 Web 端增强能力，不属于后端设置契约行。 */}
                      <LanguageRow onClick={() => setChoosingLanguage(true)} />
                    </>
                  ) : null}
                </div>
              </section>
            ))}
          </div>
        </div>
      </div>

      {isChoosingLanguage ? (
        <div className="fixed inset-0 z-10 flex items-center justify-center bg-black/30 p-4">
          <div className="w-full max-w-sm rounded-lg bg-surface-primary p-5 shadow-xl">
            <h3 className="text-base font-semibold text-label-primary">{t.setting.language}</h3>
            <div className="mt-4 space-y-2">
              {[
                { locale: 'zh-Hans' as const, label: t.setting.simplifiedChinese },
                { locale: 'en' as const, label: t.setting.english },
              ].map((option) => (
                <button
                  key={option.locale}
                  className={[
                    'flex h-11 w-full items-center justify-between rounded-control px-3 text-left text-sm font-medium transition',
                    locale === option.locale
                      ? 'bg-accent-secondary text-accent-primary'
                      : 'text-label-secondary hover:bg-surface-secondary hover:text-label-primary',
                  ].join(' ')}
                  type="button"
                  onClick={() => {
                    setLocale(option.locale);
                    setChoosingLanguage(false);
                  }}
                >
                  {option.label}
                  {locale === option.locale ? <span aria-hidden="true">✓</span> : null}
                </button>
              ))}
            </div>
            <div className="mt-5 flex justify-end">
              <button
                className="h-10 rounded-control border border-separator px-4 text-sm font-medium text-label-secondary transition hover:text-label-primary"
                type="button"
                onClick={() => setChoosingLanguage(false)}
              >
                {t.setting.cancel}
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {isConfirmingLogout ? (
        <div className="fixed inset-0 z-10 flex items-center justify-center bg-black/30 p-4">
          <div className="w-full max-w-sm rounded-lg bg-surface-primary p-5 shadow-xl">
            <h3 className="text-base font-semibold text-label-primary">
              {t.setting.confirmLogoutTitle}
            </h3>
            <div className="mt-5 flex justify-end gap-2">
              <button
                className="h-10 rounded-control border border-separator px-4 text-sm font-medium text-label-secondary transition hover:text-label-primary"
                type="button"
                disabled={isLoggingOut}
                onClick={() => setConfirmingLogout(false)}
              >
                {t.setting.cancel}
              </button>
              <button
                className="inline-flex h-10 items-center gap-2 rounded-control bg-mark px-4 text-sm font-medium text-white transition hover:bg-mark/90 disabled:opacity-60"
                type="button"
                disabled={isLoggingOut}
                onClick={() => {
                  void confirmLogout();
                }}
              >
                {isLoggingOut ? <Loader2 aria-hidden="true" className="animate-spin" size={16} /> : null}
                {t.setting.confirm}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}

function LanguageRow({ onClick }: { onClick: () => void }) {
  const { locale, t } = useI18n();
  return (
    <button
      className="flex min-h-12 w-full items-center justify-between gap-3 border-b border-separator px-4 py-3 text-left text-sm text-label-primary transition hover:bg-surface-secondary last:border-b-0"
      type="button"
      onClick={onClick}
    >
      <span>{t.setting.language}</span>
      <span className="flex items-center gap-2 text-label-tertiary">
        {locale === 'en' ? t.setting.english : t.setting.simplifiedChinese}
        <ChevronRight aria-hidden="true" size={16} />
      </span>
    </button>
  );
}

function SettingRowItem({
  row,
  disabled,
  onClose,
  onConfirmLogout,
}: {
  row: SettingRow;
  disabled: boolean;
  onClose: () => void;
  onConfirmLogout: () => void;
}) {
  const { t } = useI18n();
  const title = t.setting.rows[row.kind];
  // 后端契约中的“未设置”交给 i18n 替换，版本号保持原样展示。
  const detail =
    row.detail === '未设置'
      ? t.setting.unset
      : row.detail === '0.1.0 (1)'
        ? row.detail
        : row.detail;
  const className = [
    'flex min-h-12 w-full items-center gap-3 border-b border-separator px-4 py-3 text-sm last:border-b-0',
    row.centered ? 'justify-center text-center' : 'justify-between text-left',
    row.selectable ? 'transition hover:bg-surface-secondary' : '',
    row.destructive ? 'font-medium text-mark' : 'text-label-primary',
  ].join(' ');

  if (row.action === 'openPrivacy') {
    return (
      <Link className={className} href="/privacy" onClick={onClose}>
        <span>{title}</span>
        <span className="flex items-center gap-2 text-label-tertiary">
          {detail}
          {row.showsDisclosure ? <ChevronRight aria-hidden="true" size={16} /> : null}
        </span>
      </Link>
    );
  }

  if (row.action === 'confirmLogout') {
    return (
      <button className={className} type="button" disabled={disabled} onClick={onConfirmLogout}>
        {title}
      </button>
    );
  }

  return (
    <div className={className}>
      <span>{title}</span>
      <span className="text-label-secondary">{detail}</span>
    </div>
  );
}
