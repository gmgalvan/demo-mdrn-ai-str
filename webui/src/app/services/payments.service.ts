import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';

import { Health, Payment, PaymentCreate } from '../models/payment';

// All requests go through the relative /api prefix so the same build works
// behind `ng serve`'s dev proxy and behind the nginx reverse proxy in Docker/k8s.
const API_BASE = '/api';

@Injectable({ providedIn: 'root' })
export class PaymentsService {
  constructor(private readonly http: HttpClient) {}

  getHealth(): Observable<Health> {
    return this.http.get<Health>(`${API_BASE}/health`);
  }

  listPayments(): Observable<Payment[]> {
    return this.http.get<Payment[]>(`${API_BASE}/payments`);
  }

  createPayment(payment: PaymentCreate): Observable<Payment> {
    return this.http.post<Payment>(`${API_BASE}/payments`, payment);
  }
}
