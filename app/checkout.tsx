import { router } from 'expo-router';

import { Screen } from '@/components/Screen';
import { EmptyState } from '@/components/States';
import { strings } from '@/lib/strings';

// Placeholder until Phase 3.
export default function Checkout() {
  return (
    <Screen title={strings.soon.checkoutTitle}>
      <EmptyState
        title={strings.soon.checkoutTitle}
        body={strings.soon.checkoutBody}
        actionLabel={strings.soon.backToCart}
        onAction={() => router.navigate('/cart')}
      />
    </Screen>
  );
}
