'use client';

import { useQuery } from '@tanstack/react-query';
import { loadHistoryPage } from './history-api';
import { mapRecordPageToSections } from './history-mappers';

export function useHistoryPage() {
  // 侧边栏目前只加载第一页历史；分页能力保留在 API 层。
  return useQuery({
    queryKey: ['history', 'page', 1, 20],
    queryFn: () => loadHistoryPage({ currentPage: 1, pageSize: 20 }),
    select: (page) => mapRecordPageToSections(page),
  });
}
