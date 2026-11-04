import { Modal, Text, View } from 'react-native';

import { strings } from '@/lib/strings';

import { Button } from './Button';

type Props = {
  visible: boolean;
  title: string;
  body: string;
  confirmLabel: string;
  onConfirm: () => void;
  onCancel: () => void;
};

/** A confirmation that works on web too, where native alerts do nothing. */
export function ConfirmDialog({ visible, title, body, confirmLabel, onConfirm, onCancel }: Props) {
  return (
    <Modal animationType="fade" onRequestClose={onCancel} transparent visible={visible}>
      <View className="flex-1 items-center justify-center bg-ink/50 px-4">
        <View accessibilityRole="alert" className="w-full max-w-sm rounded-2xl bg-white p-6">
          <Text className="text-xl font-bold text-ink">{title}</Text>
          <Text className="mt-2 text-base text-ink/70">{body}</Text>
          <View className="mt-6 gap-3">
            <Button label={confirmLabel} onPress={onConfirm} />
            <Button label={strings.common.cancel} onPress={onCancel} variant="plain" />
          </View>
        </View>
      </View>
    </Modal>
  );
}
