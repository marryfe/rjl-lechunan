import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react-native';

import Home from '../../app/index';
import { supabase } from '@/lib/supabase';

jest.mock('@/lib/supabase', () => ({ supabase: { from: jest.fn() } }));

function mockSettingsResponse(response: { data: unknown; error: unknown }) {
  const single = jest.fn().mockResolvedValue(response);
  const eq = jest.fn(() => ({ single }));
  const select = jest.fn(() => ({ eq }));
  (supabase.from as jest.Mock).mockReturnValue({ select });
}

async function renderHome() {
  // gcTime: Infinity stops React Query leaving a 5-minute cleanup timer running after the test.
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false, gcTime: Infinity } },
  });
  await render(
    <QueryClientProvider client={client}>
      <Home />
    </QueryClientProvider>,
  );
}

describe('Home', () => {
  it('shows the store name returned by the database', async () => {
    mockSettingsResponse({ data: { store_name: 'Name From Database' }, error: null });
    await renderHome();
    expect(await screen.findByText('Name From Database')).toBeTruthy();
    expect(supabase.from).toHaveBeenCalledWith('settings');
  });

  it('shows an error with a retry button, and no store name, when the query fails', async () => {
    mockSettingsResponse({ data: null, error: { message: 'connection refused' } });
    await renderHome();
    expect(await screen.findByText("We can't reach the shop right now.")).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Try again' })).toBeTruthy();
    expect(screen.queryByText('RJL Lechunan')).toBeNull();
  });
});
