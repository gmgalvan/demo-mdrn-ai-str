export interface PaymentCreate {
  amount: number;
  currency: string;
  description?: string;
}

export interface Payment extends PaymentCreate {
  id: number;
  status: string;
}

export interface Health {
  status: string;
}
