import { ActivityIndicator, Pressable, Text, View } from 'react-native';

import { useStoreName } from '@/api/catalog';
import { strings } from '@/lib/strings';

// Phase 0 placeholder. The name comes only from the database, so seeing it proves the connection.
export default function Home() {
  const { data: storeName, error, isPending, refetch } = useStoreName();

  return (
    <View className="flex-1 items-center justify-center bg-cream px-6">
      {isPending && <ActivityIndicator accessibilityLabel={strings.home.loading} color="#B4441C" />}

      {storeName && (
        <>
          <Text accessibilityRole="header" className="text-center text-4xl font-bold text-primary">
            {storeName}
          </Text>
          <Text className="mt-3 text-center text-base text-ink">{strings.home.connected}</Text>
        </>
      )}

      {error && !storeName && (
        <>
          <Text className="text-center text-lg font-bold text-ink">{strings.home.loadError}</Text>
          {__DEV__ && <Text className="mt-2 text-center text-sm text-ink">{error.message}</Text>}
          <Pressable
            accessibilityRole="button"
            className="mt-6 min-h-11 justify-center rounded-lg bg-primary px-6"
            onPress={() => refetch()}
          >
            <Text className="text-base font-bold text-white">{strings.home.retry}</Text>
          </Pressable>
        </>
      )}
    </View>
  );
}
