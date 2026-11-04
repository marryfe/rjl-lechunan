import { render, screen } from '@testing-library/react-native';

import Cart from '../../app/cart';
import { useMenu, useQuote } from '@/api/catalog';
import { useCartStore } from '@/features/cart/store';
import type { MenuProduct, Quote } from '@/types/api';

jest.mock('@/api/catalog', () => ({ useMenu: jest.fn(), useQuote: jest.fn() }));
jest.mock('@/components/Screen', () => ({
  Screen: ({ children, footer }: { children: React.ReactNode; footer: React.ReactNode }) => (
    <>
      {children}
      {footer}
    </>
  ),
}));
jest.mock('expo-router', () => ({ router: { navigate: jest.fn(), push: jest.fn() } }));
jest.mock('@react-native-async-storage/async-storage', () =>
  jest.requireActual('@react-native-async-storage/async-storage/jest/async-storage-mock'),
);

const chopped: MenuProduct = {
  id: 'chopped',
  name: 'Chopped Lechon',
  description: null,
  photo_path: null,
  sell_type: 'by_kg',
  price_per_kg: 750,
  min_kg: 1,
  kg_step: 0.5,
  is_active: true,
  sort_order: 1,
  categories: null,
  product_sizes: [],
  add_ons: [],
};

const quote: Quote = {
  lines: [
    {
      product_id: 'chopped',
      product_name: 'Chopped Lechon',
      size_id: null,
      size_name: null,
      kg: 5,
      qty: 1,
      unit_price: 750,
      add_ons: [],
      line_total: 3750,
    },
  ],
  freebies: [
    {
      rule_id: 'r',
      rule_name: '5 kg and up',
      inventory_item_id: 'sauce',
      item_name: 'Lechon sauce bottle',
      qty: 1,
    },
  ],
  skipped_freebies: [{ rule_name: 'PHP 15,000 and up', reason: 'OUT_OF_STOCK' }],
  pig_count: 0,
  total_kg: 5,
  subtotal: 3750,
  delivery_fee: 0,
  total: 3750,
};

function setUp(products: MenuProduct[], quoteResult: object) {
  (useMenu as jest.Mock).mockReturnValue({ data: { products, rules: [] }, isPending: false });
  (useQuote as jest.Mock).mockReturnValue(quoteResult);
}

beforeEach(async () => {
  await useCartStore.persist.rehydrate();
  useCartStore.getState().clear();
});

describe('Cart', () => {
  it('shows an empty cart with a way to the menu', async () => {
    setUp([chopped], { isError: false, isFetching: false });
    await render(<Cart />);
    expect(await screen.findByText('Your cart is empty')).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Browse the menu' })).toBeTruthy();
  });

  it('shows amounts from quote_cart, and freebies as ₱0 lines', async () => {
    useCartStore.getState().addLine({ product_id: 'chopped', kg: 5 });
    setUp([chopped], { data: quote, isError: false, isFetching: false });
    await render(<Cart />);
    expect(await screen.findByText('Chopped Lechon')).toBeTruthy();
    expect(screen.getAllByText('₱3,750')).toHaveLength(2);
    expect(screen.getByText('1 × Lechon sauce bottle')).toBeTruthy();
    expect(screen.getByText('₱0')).toBeTruthy();
  });

  it('notes a freebie that is out of stock', async () => {
    useCartStore.getState().addLine({ product_id: 'chopped', kg: 5 });
    setUp([chopped], { data: quote, isError: false, isFetching: false });
    await render(<Cart />);
    expect(
      await screen.findByText('Freebie currently unavailable: PHP 15,000 and up'),
    ).toBeTruthy();
  });

  it('marks a line that left the menu, leaves it out of the quote, and blocks checkout', async () => {
    useCartStore.getState().addLine({ product_id: 'chopped', kg: 5 });
    useCartStore.getState().addLine({ product_id: 'old', kg: 1 });
    setUp([chopped], { data: quote, isError: false, isFetching: false });
    await render(<Cart />);
    expect(await screen.findByText('No longer available')).toBeTruthy();
    expect((useQuote as jest.Mock).mock.calls.at(-1)?.[0]).toEqual([
      { product_id: 'chopped', kg: 5 },
    ]);
    expect(screen.getByRole('button', { name: 'Checkout' }).props.accessibilityState.disabled).toBe(
      true,
    );
  });

  it('shows friendly text when the quote fails', async () => {
    const { ApiError } = jest.requireActual('@/lib/errors');
    useCartStore.getState().addLine({ product_id: 'chopped', kg: 5 });
    setUp([chopped], {
      isError: true,
      error: new ApiError('PRODUCT_UNAVAILABLE: gone'),
      isFetching: false,
      refetch: jest.fn(),
    });
    await render(<Cart />);
    expect(await screen.findByText("Sorry, that item isn't available right now.")).toBeTruthy();
  });
});
