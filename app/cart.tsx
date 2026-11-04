import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import { Pressable, Text, View } from 'react-native';

import { useMenu, useQuote } from '@/api/catalog';
import { Button } from '@/components/Button';
import { ConfirmDialog } from '@/components/ConfirmDialog';
import { FreebieList } from '@/components/FreebieList';
import { Screen } from '@/components/Screen';
import { EmptyState, ErrorState, LoadingState } from '@/components/States';
import { KgStepper, QtyStepper } from '@/components/Stepper';
import { describeLine, splitLines } from '@/features/cart/lines';
import {
  isKgLine,
  toCartItems,
  useCartHydrated,
  useCartStore,
  type CartLine,
} from '@/features/cart/store';
import { formatPeso } from '@/lib/money';
import { strings } from '@/lib/strings';
import { useDebouncedValue } from '@/lib/use-debounced-value';
import type { MenuProduct, QuoteLine } from '@/types/api';

const NO_LINES = { available: [], gone: [] };

function RemoveButton({ onPress }: { onPress: () => void }) {
  return (
    <Pressable accessibilityRole="button" className="min-h-11 justify-center" onPress={onPress}>
      <Text className="text-base font-bold text-primary">{strings.common.remove}</Text>
    </Pressable>
  );
}

function LineRow({
  line,
  products,
  quoted,
  onRemove,
}: {
  line: CartLine;
  products: MenuProduct[];
  quoted: QuoteLine | undefined;
  onRemove: () => void;
}) {
  const setQty = useCartStore((state) => state.setQty);
  const setKg = useCartStore((state) => state.setKg);
  const { name, detail, addOns, product } = describeLine(line, products);

  return (
    <View className="rounded-2xl bg-white p-4">
      <View className="flex-row justify-between gap-3">
        <View className="flex-1">
          <Text className="text-base font-bold text-ink">{name}</Text>
          {detail && <Text className="text-sm text-ink/70">{detail}</Text>}
          {addOns.map((addOn) => (
            <Text key={addOn} className="text-sm text-ink/70">
              + {addOn}
            </Text>
          ))}
        </View>
        <Text className="text-base font-bold text-ink">
          {quoted ? formatPeso(quoted.line_total) : ' '}
        </Text>
      </View>
      <View className="mt-3 flex-row items-center justify-between">
        {isKgLine(line) && product ? (
          <KgStepper
            value={line.kg}
            min={product.min_kg}
            step={product.kg_step}
            onChange={(kg) => setKg(line.id, kg)}
          />
        ) : (
          !isKgLine(line) && (
            <QtyStepper value={line.qty} onChange={(qty) => setQty(line.id, qty)} />
          )
        )}
        <RemoveButton onPress={onRemove} />
      </View>
    </View>
  );
}

export default function Cart() {
  const hydrated = useCartHydrated();
  const lines = useCartStore((state) => state.lines);
  const removeLine = useCartStore((state) => state.removeLine);
  const menu = useMenu();
  const [removing, setRemoving] = useState<CartLine | null>(null);

  const products = menu.data?.products;
  const { available, gone } = useMemo(
    () => (products ? splitLines(lines, products) : NO_LINES),
    [lines, products],
  );

  const quotedLines = useDebouncedValue<CartLine[]>(available);
  const items = useMemo(() => toCartItems(quotedLines), [quotedLines]);
  const quote = useQuote(items, 'pickup', null);

  const updating = quotedLines !== available || quote.isFetching;
  // A saved quote from before a line was removed has a different number of lines.
  const quotedRows = quote.data?.lines.length === quotedLines.length ? quote.data?.lines : null;

  if (!hydrated || (lines.length > 0 && menu.isPending)) {
    return (
      <Screen title={strings.cart.title}>
        <LoadingState />
      </Screen>
    );
  }

  if (lines.length === 0) {
    return (
      <Screen title={strings.cart.title}>
        <EmptyState
          title={strings.cart.empty}
          body={strings.cart.emptyBody}
          actionLabel={strings.cart.browse}
          onAction={() => router.navigate('/menu')}
        />
      </Screen>
    );
  }

  if (menu.isError) {
    return (
      <Screen title={strings.cart.title}>
        <ErrorState error={menu.error} onRetry={() => menu.refetch()} />
      </Screen>
    );
  }

  const showTotals = available.length > 0 && !quote.isError && quote.data;

  const footer = (
    <View className="gap-3">
      {showTotals && (
        <View>
          <View className="flex-row items-center justify-between">
            <Text className="text-base text-ink">{strings.cart.subtotal}</Text>
            <Text
              className={`text-2xl font-bold text-ink ${updating ? 'opacity-40' : ''}`}
              accessibilityLabel={updating ? strings.cart.updating : undefined}
            >
              {formatPeso(quote.data.subtotal)}
            </Text>
          </View>
          <Text className="text-sm text-ink/70">{strings.cart.deliveryNote}</Text>
        </View>
      )}
      <Button
        label={strings.cart.checkout}
        disabled={updating || !showTotals || gone.length > 0}
        onPress={() => router.push('/checkout')}
      />
    </View>
  );

  return (
    <Screen title={strings.cart.title} footer={footer}>
      <View className="w-full max-w-2xl self-center">
        <Text accessibilityRole="header" className="mt-2 text-3xl font-bold text-ink">
          {strings.cart.title}
        </Text>

        <View className="mt-4 gap-3">
          {available.map((line) => (
            <LineRow
              key={line.id}
              line={line}
              products={products ?? []}
              quoted={quotedRows?.[quotedLines.findIndex((item) => item.id === line.id)]}
              onRemove={() => setRemoving(line)}
            />
          ))}

          {gone.map((line) => (
            <View
              key={line.id}
              className="flex-row items-center justify-between gap-3 rounded-2xl bg-white p-4"
            >
              <View className="flex-1">
                <Text className="text-base font-bold text-ink">
                  {describeLine(line, products ?? []).name ?? strings.cart.unknownItem}
                </Text>
                <Text className="text-sm text-ink/70">{strings.cart.gone}</Text>
              </View>
              <RemoveButton onPress={() => removeLine(line.id)} />
            </View>
          ))}
        </View>

        {quote.isError && (
          <ErrorState
            error={quote.error}
            onRetry={() => {
              // An item may have left the menu since it loaded, which is why the quote failed.
              // Fresh menu data moves that line aside, and the quote then runs on the rest.
              menu.refetch();
              quote.refetch();
            }}
          />
        )}

        {showTotals && quote.data.freebies.length > 0 && (
          <View className="mt-6">
            <Text accessibilityRole="header" className="mb-3 text-lg font-bold text-ink">
              {strings.cart.freebies}
            </Text>
            <FreebieList freebies={quote.data.freebies} />
          </View>
        )}

        {showTotals &&
          quote.data.skipped_freebies.map((skipped) => (
            <Text key={skipped.rule_name} className="mt-3 text-sm text-ink/70">
              {strings.cart.freebieUnavailable(skipped.rule_name)}
            </Text>
          ))}
      </View>

      <ConfirmDialog
        visible={removing !== null}
        title={strings.cart.removeTitle(
          removing ? (describeLine(removing, products ?? []).name ?? '') : '',
        )}
        body={strings.cart.removeBody}
        confirmLabel={strings.common.remove}
        onCancel={() => setRemoving(null)}
        onConfirm={() => {
          if (removing) removeLine(removing.id);
          setRemoving(null);
        }}
      />
    </Screen>
  );
}
