import { fireEvent, render, screen } from '@testing-library/react-native';

import { useQuote } from '@/api/catalog';
import { ProductDetail } from '@/features/menu/ProductDetail';
import type { MenuProduct } from '@/types/api';

jest.mock('@/api/catalog', () => ({ useQuote: jest.fn() }));
jest.mock('@/components/Screen', () => ({
  Screen: ({ children, footer }: { children: React.ReactNode; footer: React.ReactNode }) => (
    <>
      {children}
      {footer}
    </>
  ),
}));
jest.mock('@/components/ProductPhoto', () => ({ ProductPhoto: () => null }));
jest.mock('expo-router', () => ({ router: { navigate: jest.fn() } }));
jest.mock('@react-native-async-storage/async-storage', () =>
  jest.requireActual('@react-native-async-storage/async-storage/jest/async-storage-mock'),
);

const byKilo: MenuProduct = {
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

const decrease = () => screen.getByRole('button', { name: 'Decrease weight' });
const increase = () => screen.getByRole('button', { name: 'Increase weight' });

beforeEach(() => {
  (useQuote as jest.Mock).mockReturnValue({ data: undefined, isError: false, isFetching: false });
});

describe('Product kg stepper', () => {
  it('starts at the minimum and cannot go below it', async () => {
    await render(<ProductDetail product={byKilo} />);
    expect(screen.getByText('1 kg')).toBeTruthy();
    expect(decrease().props.accessibilityState.disabled).toBe(true);
  });

  it('moves by the product step', async () => {
    await render(<ProductDetail product={byKilo} />);
    await fireEvent.press(increase());
    expect(screen.getByText('1.5 kg')).toBeTruthy();
    await fireEvent.press(increase());
    expect(screen.getByText('2 kg')).toBeTruthy();
    await fireEvent.press(decrease());
    expect(screen.getByText('1.5 kg')).toBeTruthy();
  });

  it('follows each product own minimum and step', async () => {
    await render(<ProductDetail product={{ ...byKilo, min_kg: 2, kg_step: 0.25 }} />);
    expect(screen.getByText('2 kg')).toBeTruthy();
    await fireEvent.press(increase());
    expect(screen.getByText('2.25 kg')).toBeTruthy();
  });
});
