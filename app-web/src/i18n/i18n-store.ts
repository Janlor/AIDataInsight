'use client';

import { create } from 'zustand';

export type AppLocale = 'zh-Hans' | 'en';

const storageKey = 'aidatainsight.locale';

interface I18nStore {
  locale: AppLocale;
  isHydrated: boolean;
  hydrate: () => void;
  setLocale: (locale: AppLocale) => void;
}

export const useI18nStore = create<I18nStore>((set) => ({
  locale: 'zh-Hans',
  isHydrated: false,
  hydrate: () => {
    if (typeof window === 'undefined') {
      // SSR 阶段没有浏览器语言和 localStorage，先使用默认中文。
      set({ isHydrated: true });
      return;
    }

    const stored = normalizeLocale(window.localStorage.getItem(storageKey));
    const detected = normalizeLocale(window.navigator.language);
    // 优先使用用户显式选择的语言，其次使用浏览器语言。
    set({ locale: stored ?? detected ?? 'zh-Hans', isHydrated: true });
  },
  setLocale: (locale) => {
    if (typeof window !== 'undefined') {
      // 切换语言时同步写入 html lang，方便浏览器和辅助技术识别页面语言。
      window.localStorage.setItem(storageKey, locale);
      document.documentElement.lang = locale === 'en' ? 'en' : 'zh-Hans';
    }
    set({ locale });
  },
}));

function normalizeLocale(value: string | null | undefined): AppLocale | null {
  // 当前仅区分英文和简体中文，其它语言统一回落到中文。
  if (!value) {
    return null;
  }
  return value.toLowerCase().startsWith('en') ? 'en' : 'zh-Hans';
}
