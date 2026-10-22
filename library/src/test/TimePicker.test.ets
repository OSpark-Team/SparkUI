import { describe, it, expect } from '@ohos/hypium';
import {
  sparkFormatTime, sparkHour12, sparkHourEnabled, sparkMinuteOptions, sparkMinuteStep, sparkNearestEnabled,
  sparkNearestInHour, sparkNearestTime, sparkParseTime, sparkStepEnabled, sparkTimeInRange, sparkTimeLabel
} from '../main/ets/components/time-picker/TimePickerLogic';

export default function timePickerTest() {
  describe('TimePicker', () => {
    it('parse_and_format', 0, () => {
      expect(sparkParseTime('09:30')).assertEqual(570);
      expect(sparkParseTime('9:05')).assertEqual(545);
      expect(sparkParseTime('23:59')).assertEqual(1439);
      expect(sparkParseTime('24:00')).assertEqual(-1);
      expect(sparkParseTime('12:60')).assertEqual(-1);
      expect(sparkParseTime('abc')).assertEqual(-1);
      expect(sparkParseTime(undefined)).assertEqual(-1);
      expect(sparkFormatTime(570)).assertEqual('09:30');
      expect(sparkFormatTime(0)).assertEqual('00:00');
      expect(sparkFormatTime(1440 + 61)).assertEqual('01:01');
    });

    it('labels_12h', 0, () => {
      expect(sparkHour12(0)).assertEqual(12);
      expect(sparkHour12(13)).assertEqual(1);
      expect(sparkTimeLabel(0, true, 'AM', 'PM')).assertEqual('12:00 AM');
      expect(sparkTimeLabel(13 * 60 + 5, true, 'AM', 'PM')).assertEqual('1:05 PM');
      expect(sparkTimeLabel(13 * 60 + 5, false, 'AM', 'PM')).assertEqual('13:05');
    });

    it('minute_step', 0, () => {
      expect(sparkMinuteStep(0)).assertEqual(1);
      expect(sparkMinuteStep(90)).assertEqual(1);
      expect(sparkMinuteOptions(15).join(',')).assertEqual('0,15,30,45');
      expect(sparkMinuteOptions(1).length).assertEqual(60);
    });

    it('range', 0, () => {
      expect(sparkTimeInRange(500, -1, -1)).assertTrue();
      expect(sparkTimeInRange(500, 540, -1)).assertFalse();
      expect(sparkHourEnabled(8, 15, 540, 1050)).assertFalse();
      expect(sparkHourEnabled(17, 15, 540, 1050)).assertTrue();
      expect(sparkHourEnabled(17, 45, 1030, 1040)).assertFalse();
      expect(sparkNearestTime(7 * 60, 15, 540, 1050)).assertEqual(540);
      expect(sparkNearestTime(10 * 60 + 8, 15, -1, -1)).assertEqual(600 + 15);
      expect(sparkNearestTime(23 * 60 + 59, 15, -1, -1)).assertEqual(23 * 60 + 45);
      expect(sparkNearestTime(600, 15, 700, 650)).assertEqual(-1);
      expect(sparkNearestInHour(17, 45, 15, 540, 1050)).assertEqual(1050);
      expect(sparkNearestInHour(8, 0, 15, 540, 1050)).assertEqual(-1);
    });

    it('enabled_rows', 0, () => {
      const d = [true, false, true, true, false];
      expect(sparkNearestEnabled(d, 0)).assertEqual(1);
      expect(sparkNearestEnabled(d, 3)).assertEqual(4);
      expect(sparkNearestEnabled(d, 2)).assertEqual(1);
      expect(sparkNearestEnabled([true, true], 0)).assertEqual(-1);
      expect(sparkStepEnabled(d, 1, 1)).assertEqual(4);
      expect(sparkStepEnabled(d, 1, -1)).assertEqual(1);
    });
  });
}
