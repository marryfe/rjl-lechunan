import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import { Pressable, Text, View } from 'react-native';

import { useQuote } from '@/api/catalog';
import { Button } from '@/components/Button';
import { FreebieList } from '@/components/FreebieList';
import { ProductPhoto } from '@/components/ProductPhoto';
import { Screen } from '@/components/Screen';
import { KgStepper, QtyStepper } from '@/components/Stepper';
import { useCartStore } from '@/features/cart/store';
import { friendlyError } from '@/lib/errors';
import { formatPeso } from '@/lib/money';
import { strings } from '@/lib/strings';
import { colors } from '@/lib/theme';
import { useDebouncedValue } from '@/lib/use-debounced-value';
import type { CartItem, MenuProduct } from '@/types/api';

function Heading({ children }: { children: string }) {
  return (
    <Text accessibilityRole="header" className="mt-6 text-lg font-bold text-ink">
      {children}
    </Text>
  );
}

function SizeOption({
  size,
  selected,
  onPress,
}: {
  size: MenuProduct['product_sizes'][number];
  selected: boolean;
  onPress: () => void;
}) {
  const details = [
    size.approx_weight_kg === null ? null : strings.product.approxKg(size.approx_weight_kg),
    size.serves,
  ].filter(Boolean);

  return (
    <Pressable
      accessibilityRole="radio"
      accessibilityState={{ checked: selected }}
      className={`min-h-16 flex-row items-center justify-between gap-3 rounded-2xl border-2 bg-white p-4 ${selected ? 'border-primary' : 'border-transparent'}`}
      onPress={onPress}
    >
      <View className="flex-1">
        <Text className="text-base font-bold text-ink">{size.name}</Text>
        {details.map((detail) => (
          <Text key={detail} className="text-sm text-ink/70">
            {detail}
          </Text>
        ))}
      </View>
      <Text className="text-base font-bold text-primary">{formatPeso(size.price)}</Text>
    </Pressable>
  );
}

function AddOnOption({
  addOn,
  checked,
  onPress,
}: {
  addOn: MenuProduct['add_ons'][number];
  checked: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityRole="checkbox"
      accessibilityState={{ checked }}
      className="min-h-12 flex-row items-center gap-3"
      onPress={onPress}
    >
      <MaterialCommunityIcons
        name={checked ? 'checkbox-marked' : 'checkbox-blank-outline'}
        size={24}
        color={colors.primary}
      />
      <Text className="flex-1 text-base text-ink">{addOn.name}</Text>
      <Text className="text-base text-ink">+{formatPeso(addOn.price)}</Text>
    </Pressable>
  );
}

export function ProductDetail({ product }: { product: MenuProduct }) {
  const addLine = useCartStore((state) => state.addLine);
  const bySize = product.sell_type === 'by_size';

  const [sizeId, setSizeId] = useState<string | null>(null);
  const [qty, setQty] = useState(1);
  const [addOnIds, setAddOnIds] = useState<string[]>([]);
  const [kg, setKg] = useState(product.min_kg);
  const [addedSelection, setAddedSelection] = useState<CartItem | null>(null);

  const selection = useMemo<CartItem | null>(() => {
    if (!bySize) return { product_id: product.id, kg };
    if (!sizeId) return null;
    return { product_id: product.id, size_id: sizeId, qty, add_on_ids: addOnIds };
  }, [bySize, product.id, kg, sizeId, qty, addOnIds]);

  // The "added" message lasts until the customer changes their choice.
  const added = selection !== null && selection === addedSelection;

  const quotedSelection = useDebouncedValue(selection);
  const items = useMemo(() => (quotedSelection ? [quotedSelection] : []), [quotedSelection]);
  const quote = useQuote(items, 'pickup', null);
  const quoteReady = selection !== null && quotedSelection === selection && !quote.isFetching;

  function toggleAddOn(id: string) {
    setAddOnIds((current) =>
      current.includes(id) ? current.filter((item) => item !== id) : [...current, id],
    );
  }

  const footer = added ? (
    <View className="flex-row items-center justify-between gap-3">
      <Text className="flex-1 text-base font-bold text-ink">{strings.product.added}</Text>
      <Button label={strings.product.viewCart} onPress={() => router.navigate('/cart')} />
    </View>
  ) : (
    <View className="flex-row items-center justify-between gap-3">
      <View className="flex-1">
        {selection === null ? (
          <Text className="text-sm text-ink/70">{strings.product.pickSizeFirst}</Text>
        ) : quote.isError ? (
          <Text className="text-sm text-ink">{friendlyError(quote.error)}</Text>
        ) : (
          <Text className={`text-2xl font-bold text-ink ${quoteReady ? '' : 'opacity-40'}`}>
            {quote.data ? formatPeso(quote.data.total) : ' '}
          </Text>
        )}
      </View>
      <Button
        label={strings.product.addToCart}
        disabled={selection === null || quote.isError}
        onPress={() => {
          if (selection) addLine(selection);
          setAddedSelection(selection);
        }}
      />
    </View>
  );

  return (
    <Screen title={product.name} footer={footer}>
      <Pressable
        accessibilityRole="link"
        className="min-h-11 flex-row items-center gap-1"
        onPress={() => router.navigate('/menu')}
      >
        <MaterialCommunityIcons name="chevron-left" size={22} color={colors.primary} />
        <Text className="text-base font-bold text-primary">{strings.common.backToMenu}</Text>
      </Pressable>

      <View className="mt-1 gap-6 md:flex-row">
        <View className="overflow-hidden rounded-2xl md:flex-1 md:self-start">
          <ProductPhoto product={product} height={208} />
        </View>

        <View className="md:flex-1">
          <Text accessibilityRole="header" className="text-3xl font-bold text-ink">
            {product.name}
          </Text>
          {product.description && (
            <Text className="mt-2 text-base text-ink/70">{product.description}</Text>
          )}

          {bySize ? (
            <>
              <Heading>{strings.product.chooseSize}</Heading>
              <View accessibilityRole="radiogroup" className="mt-3 gap-2">
                {product.product_sizes.map((size) => (
                  <SizeOption
                    key={size.id}
                    size={size}
                    selected={size.id === sizeId}
                    onPress={() => setSizeId(size.id)}
                  />
                ))}
              </View>

              <Heading>{strings.product.quantity}</Heading>
              <View className="mt-3">
                <QtyStepper value={qty} onChange={setQty} />
              </View>

              {product.add_ons.length > 0 && (
                <>
                  <Heading>{strings.product.addOns}</Heading>
                  <View className="mt-1">
                    {product.add_ons.map((addOn) => (
                      <AddOnOption
                        key={addOn.id}
                        addOn={addOn}
                        checked={addOnIds.includes(addOn.id)}
                        onPress={() => toggleAddOn(addOn.id)}
                      />
                    ))}
                  </View>
                </>
              )}
            </>
          ) : (
            <>
              <Heading>{strings.product.howMuch}</Heading>
              <View className="mt-3">
                <KgStepper
                  value={kg}
                  min={product.min_kg}
                  step={product.kg_step}
                  onChange={setKg}
                />
              </View>
              <Text className="mt-2 text-sm text-ink/70">
                {strings.product.minimum(product.min_kg, product.kg_step)}
              </Text>
            </>
          )}

          {selection && quote.data && quote.data.freebies.length > 0 && (
            <>
              <Heading>{strings.product.freebies}</Heading>
              <View className="mt-3">
                <FreebieList freebies={quote.data.freebies} />
              </View>
            </>
          )}
        </View>
      </View>
    </Screen>
  );
}
