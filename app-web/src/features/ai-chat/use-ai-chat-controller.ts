'use client';

import type { ConversationMessage, FunctionModel } from '@/contracts/generated/models';
import { loadHistoryDetail } from '@/features/history/history-api';
import { useQuery } from '@tanstack/react-query';
import { analyzeFunction, loadChartData, sendLikeFeedback, streamAIResponse } from './ai-chat-api';
import {
  createAssistantTextMessage,
  createUserMessage,
  createWelcomeMessage,
  mapChartDetailToMessage,
  mapFunctionModelToMessage,
  mapHistoryRecordToMessages,
} from './ai-chat-mappers';
import { useCallback, useMemo, useState } from 'react';

export function useAIChatController(historyId: number | null) {
  // activeHistoryId 会在首次提问后由后端返回，用于后续问题续写同一会话。
  const [activeHistoryId, setActiveHistoryId] = useState<number | null>(historyId);
  const [draftMessages, setDraftMessages] = useState<ConversationMessage[]>([]);
  const [input, setInput] = useState('');
  const [isSending, setSending] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const historyDetailQuery = useQuery({
    queryKey: ['history', 'detail', historyId],
    queryFn: () => loadHistoryDetail(historyId ?? 0),
    enabled: Boolean(historyId),
    select: mapHistoryRecordToMessages,
  });

  // 有本轮草稿消息时优先展示草稿；否则展示历史回放；都没有时展示欢迎语。
  const restoredMessages = useMemo(() => historyDetailQuery.data ?? [], [historyDetailQuery.data]);
  const hasDraftMessages = draftMessages.length > 0;
  const messages = useMemo(
    () =>
      hasDraftMessages
        ? draftMessages
        : restoredMessages.length > 0
          ? restoredMessages
          : [createWelcomeMessage()],
    [draftMessages, hasDraftMessages, restoredMessages],
  );

  const canSend = input.trim().length > 0 && !isSending && !historyDetailQuery.isLoading;

  const send = useCallback(async () => {
    const question = input.trim();
    if (!question || isSending) {
      return;
    }

    const userMessage = createUserMessage(question);
    // 先把用户消息追加到当前显示列表，接口返回后再追加助手响应。
    setDraftMessages((current) => [...(current.length > 0 ? current : messages), userMessage]);
    setInput('');
    setErrorMessage(null);
    setSending(true);

    try {
      const functionModel = await analyzeFunction({
        question,
        historyId: activeHistoryId,
      });
      setActiveHistoryId(functionModel.historyId ?? activeHistoryId);

      // 函数识别结果决定后续是流式文本、参数补全提示，还是图表请求。
      await appendAssistantResponse({
        model: functionModel,
        question,
        appendMessages: (assistantMessages) => {
          setDraftMessages((current) => [...current, ...assistantMessages]);
        },
        updateMessage: (messageId, text) => {
          setDraftMessages((current) =>
            current.map((message) => (message.id === messageId ? { ...message, text } : message)),
          );
        },
      });
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : '发送失败，请稍后重试');
    } finally {
      setSending(false);
    }
  }, [activeHistoryId, input, isSending, messages]);

  const sendFeedback = useCallback(
    async (messageId: string, historyDetailId: number, feedback: 'liked' | 'disliked') => {
      const previousMessages = messages;
      // 点赞/点踩采用乐观更新，提交失败再回滚。
      setDraftMessages(
        messages.map((message) =>
          message.id === messageId ? { ...message, feedback } : message,
        ),
      );

      try {
        await sendLikeFeedback({
          historyDetailId,
          like: feedback === 'liked' ? '1' : '0',
        });
      } catch (error) {
        setDraftMessages(previousMessages);
        setErrorMessage(error instanceof Error ? error.message : '反馈提交失败，请稍后重试');
      }
    },
    [messages],
  );

  return useMemo(
    () => ({
      activeHistoryId,
      messages,
      input,
      setInput,
      isRestoringHistory: historyDetailQuery.isLoading,
      isSending,
      errorMessage:
        errorMessage ??
        (historyDetailQuery.isError ? '历史详情加载失败，请稍后重试' : null),
      canSend,
      send,
      sendFeedback,
    }),
    [
      activeHistoryId,
      canSend,
      errorMessage,
      historyDetailQuery.isError,
      historyDetailQuery.isLoading,
      input,
      isSending,
      messages,
      send,
      sendFeedback,
    ],
  );
}

async function appendAssistantResponse({
  model,
  question,
  appendMessages,
  updateMessage,
}: {
  model: FunctionModel;
  question: string;
  appendMessages: (messages: ConversationMessage[]) => void;
  updateMessage: (messageId: string, text: string) => void;
}) {
  if (!model.hasTool) {
    const messageId = `assistant-stream-${Date.now()}`;
    let streamedText = '';
    appendMessages([createAssistantTextMessage(messageId, model.msg ?? '')]);

    try {
      // 非工具回答走 SSE 文本流，逐块更新同一条助手消息。
      for await (const chunk of streamAIResponse(question)) {
        streamedText += chunk;
        updateMessage(messageId, streamedText);
      }
      if (!streamedText && model.msg) {
        updateMessage(messageId, model.msg);
      }
    } catch {
      updateMessage(messageId, streamedText || model.msg || '响应生成失败，请稍后重试。');
    }
    return;
  }

  if (!model.name || !model.historyId || model.name === 'queryPerformanceType') {
    // 缺少必要参数或需要用户选择指标时，直接展示意图提示。
    appendMessages([mapFunctionModelToMessage(model)]);
    return;
  }

  try {
    // 工具调用成功后再拉取图表详情，避免聊天函数接口返回过大的图表数据。
    const chartDetail = await loadChartData(model.name, model.historyId);
    appendMessages([
      mapChartDetailToMessage({
        ...chartDetail,
        historyDetailId: chartDetail.historyDetailId ?? model.historyId,
        funcType: chartDetail.funcType ?? model.name,
      }),
    ]);
  } catch {
    appendMessages([
      {
        ...mapFunctionModelToMessage(model),
        contentKind: 'text',
        text: '图表数据加载失败，请稍后重试。',
      },
    ]);
  }
}
