export interface SourceReference {
  type: string;
  id: string;
  description: string;
}

export interface ChatRequest {
  conversationId?: string | null;
  message: string;
}

export interface ChatResult {
  conversationId: string;
  message: string;
  intent: string;
  sources: SourceReference[];
  requiresHumanHandoff: boolean;
  handoffReason: string | null;
  humanSummary: string | null;
  traceId: string;
  durationMs: number;
}

export type ChatMessageRole = 'customer' | 'assistant';

export interface ChatMessageView {
  role: ChatMessageRole;
  text: string;
  timestamp: Date;
  sources?: SourceReference[];
  requiresHumanHandoff?: boolean;
  handoffReason?: string | null;
  traceId?: string;
}
