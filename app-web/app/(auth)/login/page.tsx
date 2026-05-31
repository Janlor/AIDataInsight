'use client';

import Link from 'next/link';
import Image from 'next/image';
import { useRouter } from 'next/navigation';
import { Loader2, Lock, UserRound } from 'lucide-react';
import { FormEvent, useState } from 'react';
import { useAccountStore } from '@/data/account/session-store';
import { useI18n } from '@/i18n/use-i18n';

export default function LoginPage() {
  const router = useRouter();
  const { t } = useI18n();
  const login = useAccountStore((state) => state.login);
  const [name, setName] = useState('');
  const [pwd, setPwd] = useState('');
  const [accepted, setAccepted] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setSubmitting] = useState(false);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    if (!name.trim() || !pwd.trim()) {
      // 表单基础校验在前端完成，避免空请求进入登录接口。
      setError(t.login.missingCredentials);
      return;
    }

    if (!accepted) {
      // Web 端和移动端保持一致：未同意隐私政策时不允许登录。
      setError(t.login.missingPrivacy);
      return;
    }

    setSubmitting(true);
    try {
      await login({ name: name.trim(), pwd });
      // 登录成功后替换路由，避免浏览器返回回到登录页。
      router.replace('/ai');
    } catch (loginError) {
      setError(loginError instanceof Error ? loginError.message : t.login.failed);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="min-h-screen bg-surface-secondary px-4 py-8">
      <section className="mx-auto grid min-h-[calc(100vh-4rem)] w-full max-w-6xl items-center gap-8 lg:grid-cols-[1fr_420px]">
        <div className="max-w-2xl">
          <Image
            alt={t.brandTitle}
            className="mb-8 h-16 w-16 rounded-control shadow-panel"
            height={64}
            src="/brand/login-icon.png"
            width={64}
          />
          <h1 className="text-4xl font-semibold tracking-normal text-label-primary sm:text-5xl">{t.brandTitle}</h1>
          <p className="mt-5 max-w-xl text-base leading-7 text-label-secondary">
            {t.login.description}
          </p>
        </div>

        <form
          className="w-full rounded-lg border border-separator bg-surface-primary p-6 shadow-panel"
          onSubmit={onSubmit}
        >
          <div>
            <h2 className="text-xl font-semibold text-label-primary">{t.login.submit}</h2>
            <p className="mt-2 text-sm text-label-secondary">{t.login.formHelp}</p>
          </div>

          <label className="mt-6 block text-sm font-medium text-label-primary" htmlFor="name">
            {t.login.username}
          </label>
          <div className="mt-2 flex items-center gap-2 rounded-control border border-separator bg-surface-primary px-3">
            <UserRound aria-hidden="true" className="text-label-tertiary" size={18} />
            <input
              id="name"
              className="h-11 min-w-0 flex-1 border-0 bg-transparent text-sm outline-none"
              autoComplete="username"
              value={name}
              onChange={(event) => setName(event.target.value)}
            />
          </div>

          <label className="mt-4 block text-sm font-medium text-label-primary" htmlFor="pwd">
            {t.login.password}
          </label>
          <div className="mt-2 flex items-center gap-2 rounded-control border border-separator bg-surface-primary px-3">
            <Lock aria-hidden="true" className="text-label-tertiary" size={18} />
            <input
              id="pwd"
              className="h-11 min-w-0 flex-1 border-0 bg-transparent text-sm outline-none"
              type="password"
              autoComplete="current-password"
              value={pwd}
              onChange={(event) => setPwd(event.target.value)}
            />
          </div>

          <label className="mt-4 flex items-start gap-2 text-sm text-label-secondary">
            <input
              className="mt-1 h-4 w-4 rounded border-separator text-accent-primary"
              type="checkbox"
              checked={accepted}
              onChange={(event) => setAccepted(event.target.checked)}
            />
            <span>
              {t.login.privacyPrefix}
              <Link className="ml-1 text-accent-primary hover:underline" href="/privacy">
                {t.login.privacyPolicy}
              </Link>
            </span>
          </label>

          {error ? (
            <div className="mt-4 rounded-control border border-mark/40 bg-mark-muted px-3 py-2 text-sm text-mark">
              {error}
            </div>
          ) : null}

          <button
            className="mt-6 flex h-11 w-full items-center justify-center gap-2 rounded-control bg-accent-primary px-4 text-sm font-medium text-white transition hover:bg-accent-primary/90 disabled:cursor-not-allowed disabled:opacity-60"
            type="submit"
            disabled={isSubmitting}
          >
            {isSubmitting ? <Loader2 aria-hidden="true" className="animate-spin" size={18} /> : null}
            {isSubmitting ? t.login.submitting : t.login.submit}
          </button>
        </form>
      </section>
    </main>
  );
}
