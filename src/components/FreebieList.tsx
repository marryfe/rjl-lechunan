import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Text, View } from 'react-native';

import { formatPeso } from '@/lib/money';
import { colors } from '@/lib/theme';
import type { QuoteFreebie } from '@/types/api';

/** Freebies as ₱0 lines (PLAN 7.2). */
export function FreebieList({ freebies }: { freebies: QuoteFreebie[] }) {
  return (
    <View className="gap-2">
      {freebies.map((freebie) => (
        <View key={freebie.inventory_item_id} className="flex-row items-center gap-3">
          <MaterialCommunityIcons name="gift-outline" size={20} color={colors.primary} />
          <Text className="flex-1 text-base text-ink">
            {freebie.qty} × {freebie.item_name}
          </Text>
          <Text className="text-base font-bold text-ink">{formatPeso(0)}</Text>
        </View>
      ))}
    </View>
  );
}
