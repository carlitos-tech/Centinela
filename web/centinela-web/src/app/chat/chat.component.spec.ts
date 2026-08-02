import { ComponentFixture, TestBed } from '@angular/core/testing';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideHttpClient } from '@angular/common/http';
import { ChatComponent } from './chat.component';
import { API_BASE_URL } from '../core/api-config';
import { ChatResult } from '../core/models';

describe('ChatComponent', () => {
  let fixture: ComponentFixture<ChatComponent>;
  let component: ChatComponent;
  let httpMock: HttpTestingController;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ChatComponent],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    }).compileComponents();

    fixture = TestBed.createComponent(ChatComponent);
    component = fixture.componentInstance;
    httpMock = TestBed.inject(HttpTestingController);
    fixture.detectChanges();
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('does not send an empty draft', () => {
    component.draft = '   ';
    component.send();
    httpMock.expectNone(`${API_BASE_URL}/api/chat`);
    expect(component.messages().length).toBe(0);
  });

  it('appends the customer message immediately and the assistant reply once the API responds', () => {
    component.draft = '¿Cuál es el precio de la Lámpara Aurora?';
    component.send();

    expect(component.messages().length).toBe(1);
    expect(component.messages()[0].role).toBe('customer');
    expect(component.loading()).toBeTrue();

    const req = httpMock.expectOne(`${API_BASE_URL}/api/chat`);
    expect(req.request.method).toBe('POST');

    const mockResult: ChatResult = {
      conversationId: 'conv-1',
      message: 'La Lámpara Aurora cuesta $89.000.',
      intent: 'Price',
      sources: [{ type: 'Product', id: 'LAM-001', description: 'Lámpara Aurora' }],
      requiresHumanHandoff: false,
      handoffReason: null,
      humanSummary: null,
      traceId: 'trace-1',
      durationMs: 12,
    };
    req.flush(mockResult);

    expect(component.messages().length).toBe(2);
    expect(component.messages()[1].role).toBe('assistant');
    expect(component.messages()[1].text).toBe(mockResult.message);
    expect(component.loading()).toBeFalse();
  });

  it('shows an error message when the API call fails', () => {
    component.draft = 'hola';
    component.send();

    const req = httpMock.expectOne(`${API_BASE_URL}/api/chat`);
    req.error(new ProgressEvent('network error'));

    expect(component.errorMessage()).toBeTruthy();
    expect(component.loading()).toBeFalse();
  });
});
