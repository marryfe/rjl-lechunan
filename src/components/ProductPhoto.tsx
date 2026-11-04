import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { View } from 'react-native';

import { photoUrl } from '@/api/catalog';
import { colors } from '@/lib/theme';
import type { MenuProduct } from '@/types/api';

type Props = {
  product: Pick<MenuProduct, 'name' | 'photo_path' | 'sell_type'>;
  height: number;
};

/** The product photo, or a brand panel until the owner uploads one. */
export function ProductPhoto({ product, height }: Props) {
  if (product.photo_path) {
    return (
      <Image
        accessibilityLabel={product.name}
        contentFit="cover"
        source={photoUrl(product.photo_path)}
        style={{ width: '100%', height }}
      />
    );
  }

  return (
    <View className="items-center justify-center bg-accent/25" style={{ height }}>
      <MaterialCommunityIcons
        name={product.sell_type === 'by_size' ? 'pig-variant' : 'silverware-fork-knife'}
        size={Math.round(height * 0.4)}
        color={colors.primary}
      />
    </View>
  );
}
