import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';

import { PaymentsService } from './payments.service';

describe('PaymentsService', () => {
  let service: PaymentsService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule]
    });
    service = TestBed.inject(PaymentsService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('fetches health from /api/health', () => {
    service.getHealth().subscribe((health) => {
      expect(health.status).toBe('ok');
    });

    const req = httpMock.expectOne('/api/health');
    expect(req.request.method).toBe('GET');
    req.flush({ status: 'ok' });
  });

  it('fetches payments from /api/payments', () => {
    const payments = [{ id: 1, amount: 10, currency: 'USD', description: '', status: 'pending' }];

    service.listPayments().subscribe((result) => {
      expect(result).toEqual(payments);
    });

    const req = httpMock.expectOne('/api/payments');
    expect(req.request.method).toBe('GET');
    req.flush(payments);
  });

  it('posts a new payment to /api/payments', () => {
    const payload = { amount: 25, currency: 'USD', description: 'test' };
    const created = { id: 2, status: 'pending', ...payload };

    service.createPayment(payload).subscribe((result) => {
      expect(result).toEqual(created);
    });

    const req = httpMock.expectOne('/api/payments');
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual(payload);
    req.flush(created);
  });
});
