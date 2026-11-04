import { router, useLocalSearchParams } from 'expo-router';

import { useProduct } from '@/api/catalog';
import { Screen } from '@/components/Screen';
import { EmptyState, ErrorState, LoadingState } from '@/components/States';
import { ProductDetail } from '@/features/menu/ProductDetail';
import { strings } from '@/lib/strings';

export default function ProductScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const product = useProduct(id);

  if (product.data) {
    return <ProductDetail key={product.data.id} product={product.data} />;
  }

  return (
    <Screen title={strings.menu.title}>
      {product.isPending && <LoadingState />}
      {product.isError && <ErrorState error={product.error} onRetry={() => product.refetch()} />}
      {product.isSuccess && (
        <EmptyState
          title={strings.product.notFound}
          body={strings.product.notFoundBody}
          actionLabel={strings.common.backToMenu}
          onAction={() => router.navigate('/menu')}
        />
      )}
    </Screen>
  );
}
