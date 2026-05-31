import { AppShell } from '@/components/app-shell';

export default function MainLayout({ children }: { children: React.ReactNode }) {
  // 主布局统一包裹登录态守卫和桌面侧边栏。
  return <AppShell>{children}</AppShell>;
}
