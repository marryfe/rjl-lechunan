import { render, screen } from '@testing-library/react-native';

import Home from '../../app/index';
import { useMenu, useShopInfo } from '@/api/catalog';

jest.mock('@/api/catalog', () => ({ useShopInfo: jest.fn(), useMenu: jest.fn() }));
jest.mock('@/components/Screen', () => ({
  Screen: ({ children }: { children: React.ReactNode }) => children,
}));
jest.mock('expo-router', () => ({ router: { push: jest.fn() } }));

const shop = (overrides: object) => (useShopInfo as jest.Mock).mockReturnValue(overrides);
const shopData = {
  store_name: 'Name From Database',
  contact_mobile: '09170000000',
  messenger_url: null,
  pickup_address: null,
};

beforeEach(() => {
  (useMenu as jest.Mock).mockReturnValue({
    data: {
      products: [],
      rules: [
        {
          id: 'r',
          name: 'Rule From Database',
          trigger: 'order_amount',
          size_id: null,
          start_date: null,
          end_date: null,
          is_active: true,
        },
      ],
    },
  });
});

describe('Home', () => {
  it('shows the shop name, freebies and contact from the database', async () => {
    shop({ data: shopData, isPending: false, isError: false });
    await render(<Home />);
    expect(screen.getByText('Name From Database')).toBeTruthy();
    expect(screen.getByText('Rule From Database')).toBeTruthy();
    expect(screen.getByText('Call 09170000000')).toBeTruthy();
  });

  it('hides the Messenger link until one is set', async () => {
    shop({ data: shopData, isPending: false, isError: false });
    await render(<Home />);
    expect(screen.queryByText('Message us on Messenger')).toBeNull();
  });

  it('shows a retry button when the shop details fail to load', async () => {
    shop({ isPending: false, isError: true, error: new Error('down'), refetch: jest.fn() });
    await render(<Home />);
    expect(screen.getByRole('button', { name: 'Try again' })).toBeTruthy();
    expect(screen.queryByText('RJL Lechunan')).toBeNull();
  });
});
