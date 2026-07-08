import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';

import { Payment, PaymentCreate } from '../models/payment';
import { PaymentsService } from '../services/payments.service';

@Component({
  selector: 'app-payments-dashboard',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './payments-dashboard.component.html',
  styleUrl: './payments-dashboard.component.scss'
})
export class PaymentsDashboardComponent implements OnInit {
  healthStatus: string | null = null;
  healthError = false;

  payments: Payment[] = [];
  loadError = false;

  submitting = false;
  submitError: string | null = null;

  newPayment: PaymentCreate = { amount: 0, currency: 'USD', description: '' };

  constructor(private readonly paymentsService: PaymentsService) {}

  ngOnInit(): void {
    this.loadHealth();
    this.loadPayments();
  }

  loadHealth(): void {
    this.paymentsService.getHealth().subscribe({
      next: (health) => (this.healthStatus = health.status),
      error: () => (this.healthError = true)
    });
  }

  loadPayments(): void {
    this.paymentsService.listPayments().subscribe({
      next: (payments) => (this.payments = payments),
      error: () => (this.loadError = true)
    });
  }

  submitPayment(): void {
    this.submitting = true;
    this.submitError = null;

    this.paymentsService.createPayment(this.newPayment).subscribe({
      next: (payment) => {
        this.payments = [...this.payments, payment];
        this.newPayment = { amount: 0, currency: 'USD', description: '' };
        this.submitting = false;
      },
      error: () => {
        this.submitError = 'Could not create the payment. Please try again.';
        this.submitting = false;
      }
    });
  }
}
