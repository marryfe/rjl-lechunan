import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Linking, Pressable, Text, View } from 'react-native';

import { useMenu, useShopInfo } from '@/api/catalog';
import { Banderitas } from '@/components/Banderitas';
import { Button } from '@/components/Button';
import { Screen } from '@/components/Screen';
import { ErrorState, LoadingState } from '@/components/States';
import { currentRules } from '@/features/menu/menu';
import { manilaToday } from '@/lib/dates';
import { strings } from '@/lib/strings';
import { colors } from '@/lib/theme';

type IconName = keyof typeof MaterialCommunityIcons.glyphMap;

function ContactRow({
  icon,
  label,
  role,
  onPress,
}: {
  icon: IconName;
  label: string;
  role: 'link' | 'button';
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityRole={role}
      className="min-h-12 flex-row items-center gap-3 active:opacity-60"
      onPress={onPress}
    >
      <MaterialCommunityIcons name={icon} size={22} color={colors.primary} />
      <Text className="flex-1 text-base font-bold text-primary">{label}</Text>
    </Pressable>
  );
}

export default function Home() {
  const shop = useShopInfo();
  const menu = useMenu();

  if (shop.isPending) {
    return (
      <Screen title={strings.common.home}>
        <LoadingState />
      </Screen>
    );
  }

  if (shop.isError) {
    return (
      <Screen title={strings.common.home}>
        <ErrorState error={shop.error} onRetry={() => shop.refetch()} />
      </Screen>
    );
  }

  const { store_name: storeName, contact_mobile: mobile, messenger_url: messenger } = shop.data;
  const rules = currentRules(menu.data?.rules ?? [], manilaToday());

  return (
    <Screen title={storeName}>
      <View className="mt-2 overflow-hidden rounded-3xl bg-primary">
        <Banderitas />
        <View className="px-6 pb-8 pt-10 md:px-12 md:pb-12 md:pt-16">
          <Text accessibilityRole="header" className="text-5xl font-bold text-white md:text-6xl">
            {storeName}
          </Text>
          <Text className="mt-3 max-w-xl text-lg text-white">{strings.home.tagline}</Text>
          <View className="mt-8 md:self-start">
            <Button
              label={strings.home.orderNow}
              onPress={() => router.push('/menu')}
              variant="accent"
            />
          </View>
        </View>
      </View>

      <View className="mt-10 gap-10 md:flex-row">
        <View className="md:flex-1">
          <Text accessibilityRole="header" className="text-xl font-bold text-ink">
            {strings.home.howItWorks}
          </Text>
          <View className="mt-4 gap-5">
            {strings.home.steps.map((step, index) => (
              <View key={step.title} className="flex-row gap-4">
                <View className="h-8 w-8 items-center justify-center rounded-full bg-accent">
                  <Text className="text-base font-bold text-ink">{index + 1}</Text>
                </View>
                <View className="flex-1">
                  <Text className="text-base font-bold text-ink">{step.title}</Text>
                  <Text className="mt-1 text-base text-ink/70">{step.body}</Text>
                </View>
              </View>
            ))}
          </View>
        </View>

        <View className="gap-10 md:flex-1">
          {rules.length > 0 && (
            <View>
              <Text accessibilityRole="header" className="text-xl font-bold text-ink">
                {strings.home.freebies}
              </Text>
              <View className="mt-4 gap-2">
                {rules.map((rule) => (
                  <View key={rule.id} className="flex-row items-center gap-3">
                    <MaterialCommunityIcons name="gift-outline" size={20} color={colors.primary} />
                    <Text className="flex-1 text-base text-ink">{rule.name}</Text>
                  </View>
                ))}
              </View>
              <Text className="mt-3 text-sm text-ink/70">{strings.home.freebiesNote}</Text>
            </View>
          )}

          <View>
            <Text accessibilityRole="header" className="text-xl font-bold text-ink">
              {strings.home.contact}
            </Text>
            <View className="mt-2">
              {mobile && (
                <ContactRow
                  icon="phone-outline"
                  label={strings.home.call(mobile)}
                  role="link"
                  onPress={() => Linking.openURL(`tel:${mobile}`)}
                />
              )}
              {messenger && (
                <ContactRow
                  icon="facebook-messenger"
                  label={strings.home.messenger}
                  role="link"
                  onPress={() => Linking.openURL(messenger)}
                />
              )}
              <ContactRow
                icon="map-marker-path"
                label={strings.home.track}
                role="link"
                onPress={() => router.push('/track')}
              />
            </View>
          </View>
        </View>
      </View>
    </Screen>
  );
}
