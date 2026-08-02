import { Component, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ChatService } from '../core/chat.service';
import { ChatMessageView } from '../core/models';

@Component({
  selector: 'app-chat',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './chat.component.html',
  styleUrl: './chat.component.css',
})
export class ChatComponent {
  readonly messages = signal<ChatMessageView[]>([]);
  readonly loading = signal(false);
  readonly errorMessage = signal<string | null>(null);
  draft = '';

  private conversationId: string | null = null;

  constructor(private readonly chatService: ChatService) {}

  send(): void {
    const text = this.draft.trim();
    if (!text || this.loading()) {
      return;
    }

    this.messages.update((current) => [
      ...current,
      { role: 'customer', text, timestamp: new Date() },
    ]);
    this.draft = '';
    this.loading.set(true);
    this.errorMessage.set(null);

    this.chatService
      .sendMessage({ conversationId: this.conversationId, message: text })
      .subscribe({
        next: (result) => {
          this.conversationId = result.conversationId;
          this.messages.update((current) => [
            ...current,
            {
              role: 'assistant',
              text: result.message,
              timestamp: new Date(),
              sources: result.sources,
              requiresHumanHandoff: result.requiresHumanHandoff,
              handoffReason: result.handoffReason,
              traceId: result.traceId,
            },
          ]);
          this.loading.set(false);
        },
        error: () => {
          this.errorMessage.set(
            'No se pudo conectar con el servicio de Centinela. Verifica que la API local esté disponible e intenta nuevamente.'
          );
          this.loading.set(false);
        },
      });
  }

  onKeydown(event: KeyboardEvent): void {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      this.send();
    }
  }
}
