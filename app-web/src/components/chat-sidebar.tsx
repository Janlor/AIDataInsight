'use client';

import Link from 'next/link';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { MessageSquarePlus, Trash2 } from 'lucide-react';
import { useState } from 'react';
import { useAccountStore } from '@/data/account/session-store';
import { deleteHistory } from '@/features/history/history-api';
import { useHistoryPage } from '@/features/history/use-history-page';
import { getDisplayName, getInitials } from '@/features/setting/setting-contract';
import { SettingModal } from '@/features/setting/setting-modal';
import { interpolate, useI18n } from '@/i18n/use-i18n';

export function ChatSidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const { t } = useI18n();
  const searchParams = useSearchParams();
  const queryClient = useQueryClient();
  const session = useAccountStore((state) => state.session);
  const user = useAccountStore((state) => state.user);
  const historyQuery = useHistoryPage();
  const [isSettingOpen, setSettingOpen] = useState(false);
  const [deletedIds, setDeletedIds] = useState<Set<string>>(() => new Set());
  const activeHistoryId = searchParams.get('historyId');
  // 删除后先在本地过滤，等待 React Query 重新拉取历史列表。
  const sections = (historyQuery.data ?? [])
    .map((section) => ({
      ...section,
      items: section.items.filter((item) => !deletedIds.has(item.id)),
    }))
    .filter((section) => section.items.length > 0);
  const displayName = getDisplayName(session, user, t.common.unknownUser);
  const initials = getInitials(displayName);
  const deleteMutation = useMutation({
    mutationFn: deleteHistory,
    onSuccess: (_, historyId) => {
      const deletedId = String(historyId);
      setDeletedIds((current) => new Set(current).add(deletedId));
      void queryClient.invalidateQueries({ queryKey: ['history'] });
      if (pathname === '/ai' && activeHistoryId === deletedId) {
        // 当前正在查看的会话被删除时，回到空白新会话。
        router.replace('/ai');
      }
    },
  });

  return (
    <aside className="fixed inset-y-0 left-0 hidden w-72 flex-col border-r border-separator bg-surface-primary lg:flex">
      <div className="border-b border-separator p-3">
        <h1 className="mb-2 px-3 text-sm font-semibold text-label-primary">{t.brandTitle}</h1>
        <Link
          className="flex h-10 items-center gap-3 rounded-control px-3 text-sm font-medium text-label-primary transition hover:bg-surface-secondary"
          href="/ai"
          onClick={(event) => {
            event.preventDefault();
            // 使用查询参数触发聊天页 key 变化，实现真正的新会话。
            router.push(`/ai?newChat=${Date.now()}`);
          }}
        >
          <MessageSquarePlus aria-hidden="true" size={18} />
          {t.shell.newChat}
        </Link>
      </div>

      <div className="flex-1 overflow-y-auto px-3 py-4">
        {historyQuery.isLoading ? (
          <p className="px-3 text-sm text-label-secondary">{t.sidebar.loadingHistory}</p>
        ) : null}
        {historyQuery.isError ? (
          <p className="px-3 text-sm text-mark">{t.sidebar.historyError}</p>
        ) : null}
        {sections.map((section) => (
          <section key={section.kind} className="mb-5">
            <h2 className="mb-2 px-3 text-xs font-semibold uppercase tracking-normal text-label-tertiary">
              {t.sidebar.sections[section.kind]}
            </h2>
            <div className="space-y-1">
              {section.items.map((item) => {
                const active = pathname === '/ai' && activeHistoryId === item.id;
                const historyId = Number(item.id);
                return (
                  <div
                    key={item.id}
                    className={[
                      'group flex items-center rounded-control text-sm transition',
                      active
                        ? 'bg-accent-secondary text-accent-primary'
                        : 'text-label-secondary hover:bg-surface-secondary hover:text-label-primary',
                    ].join(' ')}
                  >
                    <Link className="min-w-0 flex-1 px-3 py-2" href={`/ai?historyId=${item.id}`}>
                      <span className="block truncate font-medium">{item.title}</span>
                      <span className="mt-1 block text-xs text-label-tertiary">{item.displayTime}</span>
                    </Link>
                    <button
                      aria-label={interpolate(t.sidebar.deleteHistory, { title: item.title })}
                      className="mr-1 flex h-8 w-8 shrink-0 items-center justify-center rounded-control text-label-tertiary opacity-0 transition hover:bg-mark-muted hover:text-mark focus:opacity-100 disabled:opacity-50 group-hover:opacity-100"
                      type="button"
                      disabled={deleteMutation.isPending || !Number.isFinite(historyId)}
                      onClick={() => deleteMutation.mutate(historyId)}
                    >
                      <Trash2 aria-hidden="true" size={15} />
                    </button>
                  </div>
                );
              })}
            </div>
          </section>
        ))}
        {!historyQuery.isLoading && !historyQuery.isError && sections.length === 0 ? (
          <p className="px-3 text-sm text-label-secondary">{t.sidebar.emptyHistory}</p>
        ) : null}
      </div>

      <div className="border-t border-separator p-3">
        <button
          aria-label={interpolate(t.sidebar.openSettings, { name: displayName })}
          className="flex w-full items-center gap-3 rounded-control px-3 py-2 text-left transition hover:bg-surface-secondary"
          type="button"
          onClick={() => setSettingOpen(true)}
        >
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-label-primary text-xs font-semibold text-white">
            {initials}
          </span>
          <span className="min-w-0">
            <span className="block truncate text-sm font-medium text-label-primary">{displayName}</span>
            <span className="block truncate text-xs text-label-tertiary">{t.sidebar.accountSubtitle}</span>
          </span>
        </button>
      </div>

      <SettingModal open={isSettingOpen} onClose={() => setSettingOpen(false)} />
    </aside>
  );
}
