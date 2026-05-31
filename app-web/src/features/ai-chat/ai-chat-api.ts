import type {
  FunctionModel,
  FunctionName,
  HistoryChartDetail,
  TemplateQuestionSet,
} from '@/contracts/generated/models';
import { aiChatEndpoint as chatEndpoint } from '@/contracts/generated/models';
import { request, streamText } from '@/data/http/http-client';
import { normalizeTemplateQuestions } from './ai-chat-mappers';
import type { FunctionAnalysisInput, LikeFeedbackInput } from './ai-chat-types';

type TemplateResponse = TemplateQuestionSet | string | null;

export async function loadTemplateQuestions() {
  // 推荐问题接口在不同 mock 里可能返回对象或 JSON 字符串，mapper 负责统一。
  const payload = await request<TemplateResponse>('/chat/template', {
    method: 'GET',
  });
  return normalizeTemplateQuestions(payload);
}

export function analyzeFunction(input: FunctionAnalysisInput) {
  // /chat/function 会创建或续写历史，并返回后续图表查询所需的函数信息。
  return request<FunctionModel>('/chat/function', {
    method: 'GET',
    query: {
      question: input.question,
      historyId: input.historyId ?? undefined,
    },
  });
}

export function loadChartData(functionName: FunctionName, historyId: number) {
  return request<HistoryChartDetail>(`/chart/${functionName}`, {
    method: 'GET',
    query: { historyId },
  });
}

export function streamAIResponse(question: string) {
  // 文本流用于非工具回答或结构化分析失败后的兜底。
  return streamText(chatEndpoint.streamPath, {
    method: 'GET',
    query: { question },
  });
}

export function sendLikeFeedback(input: LikeFeedbackInput) {
  return request<null>('/history/like', {
    method: 'POST',
    body: input,
  });
}
