import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Pressable, Text, View } from 'react-native';

import { useShopInfo } from '@/api/catalog';
import { useCartStore } from '@/features/cart/store';
import { strings } from '@/lib/strings';
import { colors } from '@/lib/theme';

export function AppHeader() {
  const { data: shop } = useShopInfo();
  const count = useCartStore((state) => state.lines.length);

  return (
    <View className="w-full max-w-[1100px] flex-row items-center justify-between self-center px-4 py-1">
      <Pressable
        accessibilityRole="link"
        accessibilityLabel={strings.common.home}
        className="min-h-11 flex-1 justify-center"
        onPress={() => router.navigate('/')}
      >
        <Text className="text-lg font-bold text-primary" numberOfLines={1}>
          {shop?.store_name ?? ' '}
        </Text>
      </Pressable>
      <Pressable
        accessibilityRole="link"
        accessibilityLabel={strings.common.cartWithCount(count)}
        className="h-11 w-11 items-center justify-center"
        onPress={() => router.navigate('/cart')}
      >
        <MaterialCommunityIcons name="cart-outline" size={26} color={colors.ink} />
        {count > 0 && (
          <View className="absolute right-0 top-0 h-5 min-w-5 items-center justify-center rounded-full bg-primary px-1">
            <Text className="text-xs font-bold text-white">{count}</Text>
          </View>
        )}
      </Pressable>
    </View>
  );
}
