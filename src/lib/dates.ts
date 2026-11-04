import { formatInTimeZone } from 'date-fns-tz';

export const SHOP_TIME_ZONE = 'Asia/Manila';

/** Today's calendar date in Manila as yyyy-MM-dd, wherever the device is. */
export function manilaToday(): string {
  return formatInTimeZone(new Date(), SHOP_TIME_ZONE, 'yyyy-MM-dd');
}
