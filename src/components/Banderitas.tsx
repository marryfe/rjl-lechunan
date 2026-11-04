import { View } from 'react-native';

import { colors } from '@/lib/theme';

const FLAG_WIDTH = 20;
const FLAG_HEIGHT = 24;
const FLAG_GAP = 8;
const FLAG_COUNT = 60;
const FLAG_COLORS = [colors.accent, colors.cream];

/** Fiesta bunting hung across the hero, drawn with borders so it needs no image. */
export function Banderitas() {
  return (
    <View
      accessibilityElementsHidden
      className="overflow-hidden pt-4"
      importantForAccessibility="no-hide-descendants"
    >
      <View className="h-0.5 bg-cream/70" />
      <View className="flex-row">
        {Array.from({ length: FLAG_COUNT }, (_, index) => (
          <View
            key={index}
            style={{
              width: 0,
              height: 0,
              marginRight: FLAG_GAP,
              borderLeftWidth: FLAG_WIDTH / 2,
              borderRightWidth: FLAG_WIDTH / 2,
              borderTopWidth: FLAG_HEIGHT,
              borderLeftColor: 'transparent',
              borderRightColor: 'transparent',
              borderTopColor: FLAG_COLORS[index % FLAG_COLORS.length],
            }}
          />
        ))}
      </View>
    </View>
  );
}
