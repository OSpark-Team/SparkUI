import { describe, it, expect } from '@ohos/hypium';
import { scalePathCommands } from '../main/ets/icons/SparkIconData';
import { LUCIDE_ICONS } from '../main/ets/icons/LucideIcons';
import { SparkIconData } from '../main/ets/icons/SparkIconData';

export default function iconsTest() {
  describe('Icons', () => {
    it('scales_absolute_commands', 0, () => {
      expect(scalePathCommands('M20 6L9 17L4 12', 2)).assertEqual('M 40 12L 18 34L 8 24');
      expect(scalePathCommands('M5 12H19V4Z', 0.5)).assertEqual('M 2.5 6H 9.5V 2Z');
    });
    it('keeps_arc_rotation_and_flags', 0, () => {
      // A rx ry rotation large-arc sweep x y
      expect(scalePathCommands('M2 12A10 10 30 1 0 22 12', 3)).assertEqual('M 6 36A 30 30 30 1 0 66 36');
      // implicit repetition of arc parameters
      expect(scalePathCommands('A1 1 0 1 0 13 12 1 1 0 0 1 11 12', 2))
        .assertEqual('A 2 2 0 1 0 26 24 2 2 0 0 1 22 24');
    });
    it('handles_compact_number_syntax', 0, () => {
      expect(scalePathCommands('m6 9 6 6 6-6', 1)).assertEqual('m 6 9 6 6 6 -6');
      expect(scalePathCommands('M.5.5L1e1 2', 2)).assertEqual('M 1 1L 20 4');
    });
    it('seed_icons_are_well_formed', 0, () => {
      LUCIDE_ICONS.forEach((d: SparkIconData, name: string) => {
        expect(d.paths.length > 0).assertTrue();
        d.paths.forEach((p: string) => {
          expect(scalePathCommands(p, 1).length > 0).assertTrue();
        });
      });
    });
  });
}
