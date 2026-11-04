import { ActivityIndicator, Text, View } from 'react-native';

import { friendlyError } from '@/lib/errors';
import { strings } from '@/lib/strings';
import { colors } from '@/lib/theme';

import { Button } from './Button';

export function LoadingState() {
  return (
    <View className="items-center py-16">
      <ActivityIndicator accessibilityLabel={strings.common.loading} color={colors.primary} />
    </View>
  );
}

type EmptyProps = {
  title: string;
  body: string;
  actionLabel?: string;
  onAction?: () => void;
};

export function EmptyState({ title, body, actionLabel, onAction }: EmptyProps) {
  return (
    <View className="items-center px-4 py-16">
      <Text accessibilityRole="header" className="text-center text-xl font-bold text-ink">
        {title}
      </Text>
      <Text className="mt-2 text-center text-base text-ink/70">{body}</Text>
      {actionLabel && onAction && (
        <View className="mt-6">
          <Button label={actionLabel} onPress={onAction} />
        </View>
      )}
    </View>
  );
}

export function ErrorState({ error, onRetry }: { error: unknown; onRetry: () => void }) {
  return (
    <View className="items-center px-4 py-16">
      <Text className="text-center text-base font-bold text-ink">{friendlyError(error)}</Text>
      <View className="mt-6">
        <Button label={strings.common.retry} onPress={onRetry} />
      </View>
    </View>
  );
}
