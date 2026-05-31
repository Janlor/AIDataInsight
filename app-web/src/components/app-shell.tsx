'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { Bot, MessageSquarePlus, Settings } from 'lucide-react';
import { ReactNode, useEffect } from 'react';
import { useAccountStore } from '@/data/account/session-store';
import { useI18n } from '@/i18n/use-i18n';
import { ChatSidebar } from './chat-sidebar';

const navItems = [
  { href: '/ai', label: 'New Chat', icon: MessageSquarePlus },
  { href: '/setting', label: '设置', icon: Settings },
];

export function AppShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { t } = useI18n();
  const session = useAccountStore((state) => state.session);
  const isHydrated = useAccountStore((state) => state.isHydrated);
  const hydrate = useAccountStore((state) => state.hydrate);

  useEffect(() => {
    // AppShell 是受保护布局，进入后先恢复本地账号状态。
    hydrate();
  }, [hydrate]);

  useEffect(() => {
    if (isHydrated && !session.isLogin) {
      // hydrate 完成后仍未登录，替换到登录页，避免返回键回到受保护页面。
      router.replace('/login');
    }
  }, [isHydrated, router, session.isLogin]);

  if (!isHydrated) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-surface-secondary text-sm text-label-secondary">
        {t.shell.restoringSession}
      </main>
    );
  }

  if (!session.isLogin) {
    return null;
  }

  return (
    <div className="min-h-screen bg-surface-secondary">
      <ChatSidebar />

      <header className="sticky top-0 z-10 border-b border-separator bg-surface-primary/95 px-4 py-3 backdrop-blur lg:hidden">
        <div className="flex items-center justify-between">
          <Link className="flex items-center gap-2 text-sm font-semibold text-label-primary" href="/ai">
            <Bot aria-hidden="true" size={20} />
            {t.shell.mobileBrand}
          </Link>
          <nav className="flex items-center gap-1">
            {navItems.map((item) => {
              const Icon = item.icon;
              const active = pathname === item.href;
              return (
                <Link
                  key={item.href}
                  aria-label={item.href === '/ai' ? t.shell.newChat : t.shell.settings}
                  className={[
                    'flex h-9 w-9 items-center justify-center rounded-control',
                    active ? 'bg-accent-secondary text-accent-primary' : 'text-label-secondary',
                  ].join(' ')}
                  href={item.href}
                  onClick={
                    item.href === '/ai'
                      ? (event) => {
                          event.preventDefault();
                          // newChat 时间戳用于强制 AI 页面重建，清空当前会话状态。
                          router.push(`/ai?newChat=${Date.now()}`);
                        }
                      : undefined
                  }
                >
                  <Icon aria-hidden="true" size={18} />
                </Link>
              );
            })}
          </nav>
        </div>
      </header>

      <main className="lg:pl-72">
        <div className="mx-auto w-full max-w-6xl px-4 py-6 sm:px-6 lg:px-8">{children}</div>
      </main>
    </div>
  );
}
