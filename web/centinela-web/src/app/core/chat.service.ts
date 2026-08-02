import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { API_BASE_URL } from './api-config';
import { ChatRequest, ChatResult } from './models';

@Injectable({ providedIn: 'root' })
export class ChatService {
  constructor(private readonly http: HttpClient) {}

  sendMessage(request: ChatRequest): Observable<ChatResult> {
    return this.http.post<ChatResult>(`${API_BASE_URL}/api/chat`, request);
  }
}
