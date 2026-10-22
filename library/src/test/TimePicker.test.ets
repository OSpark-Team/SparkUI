import { describe, it, expect } from '@ohos/hypium';
import {
  sparkFormatTime, sparkHour12, sparkHourEnabled, sparkMinuteOptions, sparkMinuteStep, sparkNearestEnabled,
  sparkNearestInHour, sparkNearestTime, sparkParseTime, sparkStepEnabled, sparkTimeInRange, sparkTimeLabel,
  sparkDefaultRangeEnd, sparkFitColumnWidth, sparkTimeRangeLabel, sparkTimeRangeMinutes, sparkTimeRangeNextDay,
  sparkTimeWheelsWidth
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

    it('time_range', 0, () => {
      expect(sparkTimeRangeNextDay(9 * 60, 17 * 60)).assertFalse();
      expect(sparkTimeRangeNextDay(22 * 60, 6 * 60)).assertTrue();
      expect(sparkTimeRangeNextDay(600, 600)).assertTrue();
      expect(sparkTimeRangeNextDay(-1, 600)).assertFalse();
      expect(sparkTimeRangeNextDay(600, -1)).assertFalse();
      expect(sparkTimeRangeMinutes(9 * 60, 17 * 60 + 30)).assertEqual(510);
      expect(sparkTimeRangeMinutes(22 * 60, 6 * 60)).assertEqual(480);
      expect(sparkTimeRangeMinutes(600, 600)).assertEqual(1440);
      expect(sparkTimeRangeMinutes(-1, 600)).assertEqual(-1);
      expect(sparkTimeRangeLabel(540, 1050, false, 'AM', 'PM')).assertEqual('09:00 – 17:30');
      expect(sparkTimeRangeLabel(1320, 360, true, 'AM', 'PM')).assertEqual('10:00 PM – 6:00 AM');
      expect(sparkTimeRangeLabel(540, -1, false, 'AM', 'PM')).assertEqual('09:00 – --:--');
      expect(sparkTimeRangeLabel(-1, -1, false, 'AM', 'PM') === undefined).assertTrue();
      expect(sparkDefaultRangeEnd(540, 1)).assertEqual(600);
      expect(sparkDefaultRangeEnd(23 * 60 + 30, 15)).assertEqual(30);
      expect(sparkDefaultRangeEnd(23 * 60 + 50, 15)).assertEqual(45);
      expect(sparkDefaultRangeEnd(23 * 60 + 59, 1)).assertEqual(59);
    });

    it('wheel_layout', 0, () => {
      expect(sparkTimeWheelsWidth(56, false)).assertEqual(124);
      expect(sparkTimeWheelsWidth(56, true)).assertEqual(188);
      expect(sparkFitColumnWidth(328, 2, false, 72)).assertEqual(72);
      expect(sparkFitColumnWidth(328, 2, true, 72)).assertEqual(45);
      expect(sparkFitColumnWidth(200, 2, false, 72)).assertEqual(40);
      expect(sparkFitColumnWidth(150, 2, false, 72)).assertEqual(40);
      expect(sparkFitColumnWidth(0, 2, false, 72)).assertEqual(72);
      expect(sparkFitColumnWidth(1000, 1, true, 72)).assertEqual(72);
    });
  });
}
