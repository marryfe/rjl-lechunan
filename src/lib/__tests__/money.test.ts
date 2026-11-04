import { formatPeso } from '../money';

describe('formatPeso', () => {
  it('shows whole amounts without centavos', () => {
    expect(formatPeso(13575)).toBe('₱13,575');
    expect(formatPeso(0)).toBe('₱0');
  });

  it('shows centavos when there are any', () => {
    expect(formatPeso(1875.5)).toBe('₱1,875.50');
  });
});
