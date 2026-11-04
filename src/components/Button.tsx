import { Pressable, Text } from 'react-native';

type Variant = 'primary' | 'accent' | 'plain';

type Props = {
  label: string;
  onPress: () => void;
  variant?: Variant;
  disabled?: boolean;
};

const BOX: Record<Variant, string> = {
  primary: 'bg-primary active:opacity-80',
  accent: 'bg-accent active:opacity-80',
  plain: 'border border-primary/30 bg-transparent active:bg-primary/10',
};

const TEXT: Record<Variant, string> = {
  primary: 'text-white',
  accent: 'text-ink',
  plain: 'text-primary',
};

export function Button({ label, onPress, variant = 'primary', disabled = false }: Props) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled }}
      className={`min-h-12 items-center justify-center rounded-xl px-6 ${BOX[variant]} ${disabled ? 'opacity-40' : ''}`}
      disabled={disabled}
      onPress={onPress}
    >
      <Text className={`text-base font-bold ${TEXT[variant]}`}>{label}</Text>
    </Pressable>
  );
}
