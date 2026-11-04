import Head from 'expo-router/head';
import type { ReactNode } from 'react';
import { ScrollView, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { AppHeader } from './AppHeader';

type Props = {
  title: string;
  children: ReactNode;
  // Stays at the bottom of the screen, within thumb reach, for the main action.
  footer?: ReactNode;
};

const PAGE = 'w-full max-w-[1100px] self-center px-4';

export function Screen({ title, children, footer }: Props) {
  const insets = useSafeAreaInsets();

  return (
    <View className="flex-1 bg-cream" style={{ paddingTop: insets.top }}>
      <Head>
        <title>{title}</title>
      </Head>
      <AppHeader />
      <ScrollView className="flex-1" contentContainerClassName="pb-8">
        <View className={PAGE}>{children}</View>
      </ScrollView>
      {footer && (
        <View
          className="border-t border-ink/10 bg-white"
          style={{ paddingBottom: Math.max(insets.bottom, 12) }}
        >
          <View className={`${PAGE} pt-3`}>{footer}</View>
        </View>
      )}
    </View>
  );
}
