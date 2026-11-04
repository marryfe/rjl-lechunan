import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Pressable, Text, useWindowDimensions, View } from 'react-native';

import { useMenu } from '@/api/catalog';
import { ProductPhoto } from '@/components/ProductPhoto';
import { Screen } from '@/components/Screen';
import { EmptyState, ErrorState, LoadingState } from '@/components/States';
import { currentRules, fromPrice, hasFreebie, toSections } from '@/features/menu/menu';
import { manilaToday } from '@/lib/dates';
import { formatPeso } from '@/lib/money';
import { strings } from '@/lib/strings';
import { colors } from '@/lib/theme';
import type { MenuProduct } from '@/types/api';

const TWO_COLUMNS_FROM = 640;
const THREE_COLUMNS_FROM = 1000;

function priceLabel(product: MenuProduct): string | null {
  if (product.sell_type === 'by_kg') {
    return product.price_per_kg === null
      ? null
      : strings.menu.perKg(formatPeso(product.price_per_kg));
  }
  const lowest = fromPrice(product);
  return lowest === null ? null : strings.menu.from(formatPeso(lowest));
}

function ProductCard({ product, freebie }: { product: MenuProduct; freebie: boolean }) {
  const price = priceLabel(product);

  return (
    <Pressable
      accessibilityRole="link"
      className="overflow-hidden rounded-2xl bg-white active:opacity-80"
      onPress={() => router.push({ pathname: '/product/[id]', params: { id: product.id } })}
    >
      <ProductPhoto product={product} height={144} />
      <View className="p-4">
        <Text className="text-lg font-bold text-ink">{product.name}</Text>
        {product.description && (
          <Text className="mt-1 text-sm text-ink/70" numberOfLines={2}>
            {product.description}
          </Text>
        )}
        <View className="mt-3 flex-row items-center justify-between">
          {price && <Text className="text-lg font-bold text-primary">{price}</Text>}
          <Text className="text-sm text-ink/70">
            {product.sell_type === 'by_kg' ? strings.menu.byKilo : strings.menu.bySize}
          </Text>
        </View>
        {freebie && (
          <View className="mt-3 flex-row items-center gap-2">
            <MaterialCommunityIcons name="gift-outline" size={16} color={colors.primary} />
            <Text className="text-sm font-bold text-primary">{strings.menu.withFreebies}</Text>
          </View>
        )}
      </View>
    </Pressable>
  );
}

export default function Menu() {
  const menu = useMenu();
  const { width } = useWindowDimensions();
  const columns = width >= THREE_COLUMNS_FROM ? 3 : width >= TWO_COLUMNS_FROM ? 2 : 1;

  return (
    <Screen title={strings.menu.title}>
      <Text accessibilityRole="header" className="mt-2 text-3xl font-bold text-ink">
        {strings.menu.title}
      </Text>

      {menu.isPending && <LoadingState />}
      {menu.isError && <ErrorState error={menu.error} onRetry={() => menu.refetch()} />}
      {menu.data?.products.length === 0 && (
        <EmptyState title={strings.menu.empty} body={strings.menu.emptyBody} />
      )}

      {menu.data &&
        toSections(menu.data.products).map((section) => {
          const rules = currentRules(menu.data.rules, manilaToday());
          return (
            <View key={section.category?.id ?? 'other'} className="mt-6">
              <Text accessibilityRole="header" className="text-xl font-bold text-ink">
                {section.category?.name ?? strings.menu.other}
              </Text>
              <View className="-mx-2 mt-2 flex-row flex-wrap">
                {section.products.map((product) => (
                  <View key={product.id} className="p-2" style={{ width: `${100 / columns}%` }}>
                    <ProductCard product={product} freebie={hasFreebie(product, rules)} />
                  </View>
                ))}
              </View>
            </View>
          );
        })}
    </Screen>
  );
}
