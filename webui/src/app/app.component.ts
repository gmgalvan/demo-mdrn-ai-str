import { Component } from '@angular/core';

import { PaymentsDashboardComponent } from './payments-dashboard/payments-dashboard.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [PaymentsDashboardComponent],
  templateUrl: './app.component.html',
  styleUrl: './app.component.scss'
})
export class AppComponent {
  title = 'webui';
}
