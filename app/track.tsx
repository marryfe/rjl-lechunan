import { router } from 'expo-router';

import { Screen } from '@/components/Screen';
import { EmptyState } from '@/components/States';
import { strings } from '@/lib/strings';

// Placeholder until Phase 3.
export default function Track() {
  return (
    <Screen title={strings.soon.trackTitle}>
      <EmptyState
        title={strings.soon.trackTitle}
        body={strings.soon.trackBody}
        actionLabel={strings.common.backToMenu}
        onAction={() => router.navigate('/menu')}
      />
    </Screen>
  );
}
