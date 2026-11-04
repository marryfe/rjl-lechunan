import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Pressable, Text, View } from 'react-native';

import { MAX_KG, MAX_QTY, MIN_QTY, stepKg } from '@/features/cart/limits';
import { strings } from '@/lib/strings';
import { colors } from '@/lib/theme';

type StepperProps = {
  display: string;
  label: string;
  canDecrease: boolean;
  canIncrease: boolean;
  onDecrease: () => void;
  onIncrease: () => void;
};

function StepButton({
  icon,
  label,
  disabled,
  onPress,
}: {
  icon: 'minus' | 'plus';
  label: string;
  disabled: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled }}
      className={`h-11 w-11 items-center justify-center rounded-xl bg-primary/10 active:bg-primary/20 ${disabled ? 'opacity-40' : ''}`}
      disabled={disabled}
      onPress={onPress}
    >
      <MaterialCommunityIcons name={icon} size={20} color={colors.primary} />
    </Pressable>
  );
}

function Stepper({
  display,
  label,
  canDecrease,
  canIncrease,
  onDecrease,
  onIncrease,
}: StepperProps) {
  return (
    <View className="flex-row items-center">
      <StepButton
        icon="minus"
        label={strings.stepper.decrease(label)}
        disabled={!canDecrease}
        onPress={onDecrease}
      />
      <Text className="min-w-16 px-2 text-center text-base font-bold text-ink">{display}</Text>
      <StepButton
        icon="plus"
        label={strings.stepper.increase(label)}
        disabled={!canIncrease}
        onPress={onIncrease}
      />
    </View>
  );
}

export function QtyStepper({
  value,
  onChange,
}: {
  value: number;
  onChange: (qty: number) => void;
}) {
  return (
    <Stepper
      display={String(value)}
      label={strings.stepper.quantity}
      canDecrease={value > MIN_QTY}
      canIncrease={value < MAX_QTY}
      onDecrease={() => onChange(value - 1)}
      onIncrease={() => onChange(value + 1)}
    />
  );
}

type KgStepperProps = {
  value: number;
  min: number;
  step: number;
  onChange: (kg: number) => void;
};

export function KgStepper({ value, min, step, onChange }: KgStepperProps) {
  const rules = { min, step, max: MAX_KG };

  return (
    <Stepper
      display={strings.stepper.kg(value)}
      label={strings.stepper.weight}
      canDecrease={stepKg(value, -1, rules) !== value}
      canIncrease={stepKg(value, 1, rules) !== value}
      onDecrease={() => onChange(stepKg(value, -1, rules))}
      onIncrease={() => onChange(stepKg(value, 1, rules))}
    />
  );
}
