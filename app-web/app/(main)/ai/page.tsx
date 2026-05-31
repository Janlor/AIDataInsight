'use client';

import type { ConversationMessage } from '@/contracts/generated/models';
import { Loader2, SendHorizonal, ThumbsDown, ThumbsUp } from 'lucide-react';
import { FormEvent, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { ChartMessage } from '@/features/ai-chat/chart-message';
import { useAIChatController } from '@/features/ai-chat/use-ai-chat-controller';
import { useTemplateQuestions } from '@/features/ai-chat/use-template-questions';
import { useI18n } from '@/i18n/use-i18n';

export default function AIPage() {
  const { t } = useI18n();
  return (
    <Suspense fallback={<div className="text-sm text-label-secondary">{t.ai.loading}</div>}>
      <AIPageContent />
    </Suspense>
  );
}

function AIPageContent() {
  const searchParams = useSearchParams();
  const historyId = parseHistoryId(searchParams.get('historyId'));
  const newChatId = searchParams.get('newChat') ?? 'initial';

  // key 根据 historyId/newChat 变化，确保切换历史或新会话时重建聊天控制器。
  return <AIWorkspace key={historyId ? `history-${historyId}` : `new-${newChatId}`} historyId={historyId} />;
}

function AIWorkspace({ historyId }: { historyId: number | null }) {
  const { t } = useI18n();
  const templateQuery = useTemplateQuestions();
  const chat = useAIChatController(historyId);
  const templateQuestions = templateQuery.data ?? t.ai.defaultQuestions;
  // 只有新会话欢迎态展示推荐问题，历史回放或发送中都隐藏。
  const showSuggestions = !historyId && chat.messages.length <= 1 && !chat.isSending;

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    void chat.send();
  }

  return (
    <div className="flex min-h-[calc(100vh-3rem)] flex-col">
      {chat.errorMessage ? (
        <div className="mb-4 rounded-control border border-mark/40 bg-mark-muted px-3 py-2 text-sm text-mark">
          {chat.errorMessage}
        </div>
      ) : null}

      <section className="flex flex-1 flex-col rounded-lg border border-separator bg-surface-primary shadow-sm">
        <div className="flex-1 space-y-4 overflow-y-auto p-4 sm:p-6">
          {showSuggestions ? (
            <div className="mx-auto flex min-h-[52vh] max-w-3xl flex-col justify-center">
              <h1 className="text-2xl font-semibold text-label-primary">{t.ai.promptTitle}</h1>
              <p className="mt-2 text-sm text-label-secondary">{t.ai.promptDescription}</p>
              <div className="mt-6 grid gap-3 sm:grid-cols-2">
                {templateQuery.isLoading ? (
                  <div className="rounded-lg border border-separator bg-surface-secondary p-4 text-sm text-label-secondary">
                    {t.ai.loadingQuestions}
                  </div>
                ) : null}
                {templateQuestions.map((question) => (
                  <button
                    key={question}
                    className="rounded-lg border border-separator bg-surface-primary p-4 text-left text-sm text-label-primary shadow-sm transition hover:border-accent-primary/40 hover:bg-accent-secondary"
                    type="button"
                    onClick={() => chat.setInput(question)}
                  >
                    {question}
                  </button>
                ))}
              </div>
              {templateQuery.isError ? (
                <p className="mt-3 text-sm text-warning">{t.ai.questionError}</p>
              ) : null}
            </div>
          ) : null}

          {!showSuggestions && chat.isRestoringHistory ? (
            <div className="flex items-center justify-center gap-2 py-10 text-sm text-label-secondary">
              <Loader2 aria-hidden="true" className="animate-spin" size={18} />
              {t.ai.restoringHistory}
            </div>
          ) : null}
          {!showSuggestions
            ? chat.messages.map((message) => (
                <div
                  key={message.id}
                  className={message.role === 'user' ? 'flex justify-end' : 'flex justify-start'}
                >
                  <div
                    className={[
                      'max-w-[min(720px,85%)] rounded-lg px-4 py-3 text-sm leading-6',
                      message.role === 'user'
                        ? 'bg-accent-primary text-white'
                        : 'border border-separator bg-surface-secondary text-label-primary',
                    ].join(' ')}
                  >
                    <MessageContent
                      message={message}
                      onFeedback={(feedback) => {
                        if (message.historyDetailId) {
                          void chat.sendFeedback(message.id, message.historyDetailId, feedback);
                        }
                      }}
                    />
                  </div>
                </div>
              ))
            : null}
          {chat.isSending ? (
            <div className="flex justify-start">
              <div className="flex items-center gap-2 rounded-lg border border-separator bg-surface-secondary px-4 py-3 text-sm text-label-secondary">
                <Loader2 aria-hidden="true" className="animate-spin" size={16} />
                {t.ai.analyzing}
              </div>
            </div>
          ) : null}
        </div>

        <form className="border-t border-separator p-3 sm:p-4" onSubmit={onSubmit}>
          <div className="flex items-end gap-2 rounded-lg border border-separator bg-surface-primary p-2">
            <textarea
              className="min-h-11 flex-1 resize-none border-0 bg-transparent px-2 py-2 text-sm outline-none"
              rows={1}
              value={chat.input}
              onChange={(event) => chat.setInput(event.target.value)}
              placeholder={t.ai.inputPlaceholder}
            />
            <button
              aria-label={t.ai.send}
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-control bg-accent-primary text-white transition hover:bg-accent-primary/90 disabled:opacity-50"
              type="submit"
              disabled={!chat.canSend}
            >
              {chat.isSending ? (
                <Loader2 aria-hidden="true" className="animate-spin" size={18} />
              ) : (
                <SendHorizonal aria-hidden="true" size={18} />
              )}
            </button>
          </div>
        </form>
      </section>
    </div>
  );
}

function MessageContent({
  message,
  onFeedback,
}: {
  message: ConversationMessage;
  onFeedback: (feedback: 'liked' | 'disliked') => void;
}) {
  const { t } = useI18n();
  if (message.contentKind === 'chart') {
    // 图表消息附带点赞/点踩，反馈绑定后端 historyDetailId。
    return (
      <div>
        <p className="font-medium">{t.ai.chartResult}</p>
        <ChartMessage payload={message.chartPayload} />
        <FeedbackActions message={message} onFeedback={onFeedback} />
      </div>
    );
  }

  if (message.contentKind === 'intent') {
    // 意图消息表示后端需要更多参数，当前先用文案提示用户补充。
    return (
      <div>
        <p>{message.text ?? t.ai.intentFallback}</p>
        {message.functionName ? (
          <p className="mt-2 text-xs text-label-tertiary">Function: {message.functionName}</p>
        ) : null}
        <FeedbackActions message={message} onFeedback={onFeedback} />
      </div>
    );
  }

  return (
    <div>
      <p>{message.text ?? ''}</p>
      <FeedbackActions message={message} onFeedback={onFeedback} />
    </div>
  );
}

function FeedbackActions({
  message,
  onFeedback,
}: {
  message: ConversationMessage;
  onFeedback: (feedback: 'liked' | 'disliked') => void;
}) {
  const { t } = useI18n();
  if (message.role !== 'assistant' || !message.historyDetailId) {
    // 只有落库的助手回答才允许反馈，欢迎语和本地临时消息不展示操作。
    return null;
  }

  return (
    <div className="mt-3 flex items-center gap-2">
      <button
        aria-label={t.ai.liked}
        className={[
          'flex h-8 w-8 items-center justify-center rounded-control border transition',
          message.feedback === 'liked'
            ? 'border-accent-primary bg-accent-secondary text-accent-primary'
            : 'border-separator bg-surface-primary text-label-tertiary hover:text-label-primary',
        ].join(' ')}
        type="button"
        onClick={() => onFeedback('liked')}
      >
        <ThumbsUp aria-hidden="true" size={15} />
      </button>
      <button
        aria-label={t.ai.disliked}
        className={[
          'flex h-8 w-8 items-center justify-center rounded-control border transition',
          message.feedback === 'disliked'
            ? 'border-mark bg-mark-muted text-mark'
            : 'border-separator bg-surface-primary text-label-tertiary hover:text-label-primary',
        ].join(' ')}
        type="button"
        onClick={() => onFeedback('disliked')}
      >
        <ThumbsDown aria-hidden="true" size={15} />
      </button>
    </div>
  );
}

function parseHistoryId(value: string | null): number | null {
  // URL 中非法 historyId 直接视为新会话。
  if (!value) {
    return null;
  }
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}
