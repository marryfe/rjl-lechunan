// Shapes of the JSON returned by Postgres functions. Generated types call these plain `Json`.
// Keep in step with supabase/migrations/0002_functions.sql.
import type { Database } from './database';

type Enums = Database['public']['Enums'];
export type OrderStatus = Enums['order_status'];
export type FulfillmentType = Enums['fulfillment_type'];
export type PaymentType = Enums['payment_type'];
export type PaymentMethod = Enums['payment_method'];
export type MovementReason = Enums['movement_reason'];
export type UserRole = Enums['user_role'];

export type AvailabilityReason = 'CLOSED' | 'TOO_SOON' | 'TOO_FAR' | 'FULL';

export type AvailabilityDay = {
  day: string;
  pigs_left: number;
  kg_left: number;
  is_open: boolean;
  reason: AvailabilityReason | null;
};

export type CartSizeItem = {
  product_id: string;
  size_id: string;
  qty: number;
  add_on_ids?: string[];
};
export type CartKgItem = { product_id: string; kg: number };
export type CartItem = CartSizeItem | CartKgItem;

export type QuoteAddOn = { id: string; name: string; price: number };

export type QuoteLine = {
  product_id: string;
  product_name: string;
  size_id: string | null;
  size_name: string | null;
  kg: number | null;
  qty: number;
  unit_price: number;
  add_ons: QuoteAddOn[];
  line_total: number;
};

export type QuoteFreebie = {
  // Null when several rules gave this item.
  rule_id: string | null;
  rule_name: string;
  inventory_item_id: string;
  item_name: string;
  qty: number;
};

export type Quote = {
  lines: QuoteLine[];
  freebies: QuoteFreebie[];
  skipped_freebies: { rule_name: string; reason: 'OUT_OF_STOCK' }[];
  pig_count: number;
  total_kg: number;
  subtotal: number;
  delivery_fee: number;
  total: number;
};

export type PlaceOrderInput = {
  customer_name: string;
  customer_mobile: string;
  customer_email?: string | null;
  fulfillment: FulfillmentType;
  address?: string | null;
  landmark?: string | null;
  scheduled_date: string;
  time_slot: string;
  note?: string | null;
  items: CartItem[];
};

export type PlacedOrder = {
  order_no: string;
  total: number;
  scheduled_date: string;
  time_slot: string;
};

export type PublicOrder = {
  order_no: string;
  status: OrderStatus;
  scheduled_date: string;
  time_slot: string;
  fulfillment: FulfillmentType;
  subtotal: number;
  delivery_fee: number;
  total: number;
  amount_paid: number;
  balance_due: number;
  downpayment_due_at: string | null;
  items: {
    product_name: string;
    size_name: string | null;
    kg: number | null;
    qty: number;
    unit_price: number;
    add_ons: QuoteAddOn[];
    line_total: number;
  }[];
  freebies: { item_name: string; qty: number }[];
  status_history: { status: OrderStatus; created_at: string }[];
  messages: { sender: Enums['message_sender']; body: string; created_at: string }[];
};

export type PrepSheet = {
  date: string;
  pigs_by_size: { size_name: string; count: number }[];
  kg_by_product: { product_name: string; kg: number }[];
  add_ons: { name: string; qty: number }[];
  freebies: { item_name: string; qty: number }[];
  orders: {
    order_no: string;
    customer_name: string;
    time_slot: string;
    fulfillment: FulfillmentType;
    status: OrderStatus;
    balance_due: number;
  }[];
};

export type Dashboard = {
  date: string;
  orders_by_status: Partial<Record<OrderStatus, number>>;
  sales: number;
  downpayments: number;
  overdue_downpayments: {
    id: string;
    order_no: string;
    customer_name: string;
    customer_mobile: string;
    downpayment_due_at: string;
  }[];
  low_stock: {
    id: string;
    name: string;
    unit: string;
    available: number;
    reorder_level: number;
  }[];
  capacity: {
    day: string;
    pigs_booked: number;
    max_pigs: number;
    kg_booked: number;
    max_kg: number;
    is_closed: boolean;
  }[];
};

export type SalesReport = {
  days: {
    day: string;
    orders: number;
    sales: number;
    downpayments: number;
    cod_collected: number;
    refunds: number;
    cancellations: number;
  }[];
  products: {
    product_name: string;
    size_name: string | null;
    qty: number | null;
    kg: number | null;
    revenue: number;
  }[];
};
