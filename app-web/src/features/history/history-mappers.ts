import type { HistoryRecord, RecordPage } from '@/contracts/generated/models';
import type { HistorySection } from './history-types';

export function mapRecordPageToSections(page: RecordPage | null | undefined, now = new Date()): HistorySection[] {
  // 固定分桶顺序，保证侧边栏分区展示稳定。
  const buckets: Record<HistorySection['kind'], HistorySection> = {
    today: { kind: 'today', title: '今天', items: [] },
    thisMonth: { kind: 'thisMonth', title: '本月', items: [] },
    other: { kind: 'other', title: '其它', items: [] },
  };

  (page?.records ?? []).forEach((record) => {
    const sectionKind = inferSectionKind(record, now);
    buckets[sectionKind].items.push({
      id: String(record.id ?? ''),
      title: record.name || '未命名会话',
      displayTime: formatDisplayTime(record.updateTime ?? record.createTime, sectionKind),
    });
  });

  return [buckets.today, buckets.thisMonth, buckets.other].filter((section) => section.items.length > 0);
}

function inferSectionKind(record: HistoryRecord, now: Date): HistorySection['kind'] {
  // 优先按更新时间分组，缺失时退回创建时间。
  const date = parseContractDate(record.updateTime ?? record.createTime);
  if (!date) {
    return 'other';
  }

  if (
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate()
  ) {
    return 'today';
  }

  if (date.getFullYear() === now.getFullYear() && date.getMonth() === now.getMonth()) {
    return 'thisMonth';
  }

  return 'other';
}

function formatDisplayTime(value: string | null | undefined, sectionKind: HistorySection['kind']): string {
  // 不同分区使用不同粒度的时间展示，减少侧边栏视觉噪音。
  const date = parseContractDate(value);
  if (!date) {
    return '';
  }

  const month = pad2(date.getMonth() + 1);
  const day = pad2(date.getDate());

  if (sectionKind === 'today') {
    return `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
  }

  if (sectionKind === 'thisMonth') {
    return `${month}-${day}`;
  }

  return `${date.getFullYear()}-${month}-${day}`;
}

function parseContractDate(value: string | null | undefined): Date | null {
  if (!value) {
    return null;
  }
  // 后端返回 "yyyy-MM-dd HH:mm:ss"，浏览器更稳定解析 T 分隔格式。
  const date = new Date(value.replace(' ', 'T'));
  return Number.isNaN(date.getTime()) ? null : date;
}

function pad2(value: number): string {
  return String(value).padStart(2, '0');
}
