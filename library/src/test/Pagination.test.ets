import { describe, it, expect } from '@ohos/hypium';
import {
  SPARK_PAGINATION_ELLIPSIS, sparkPaginationRange, sparkPaginationSiblings
} from '../main/ets/components/pagination/PaginationRange';

const E: number = SPARK_PAGINATION_ELLIPSIS;

function str(a: number[]): string {
  return a.map((n: number) => n === E ? '…' : String(n)).join(' ');
}

export default function paginationTest() {
  describe('Pagination', () => {
    it('ellipsis_marker_is_minus_one', 0, () => {
      expect(E).assertEqual(-1);
    });
    it('empty_when_no_pages', 0, () => {
      expect(sparkPaginationRange(1, 0, 1).length).assertEqual(0);
    });
    it('all_pages_when_they_fit', 0, () => {
      expect(str(sparkPaginationRange(3, 7, 1))).assertEqual('1 2 3 4 5 6 7');
      expect(str(sparkPaginationRange(1, 5, 0))).assertEqual('1 2 3 4 5');
    });
    it('never_hides_a_single_page', 0, () => {
      // the reported bug: page 3 of 20 in compact mode showed "1 … 3 … 20"
      expect(str(sparkPaginationRange(3, 20, 0))).assertEqual('1 2 3 … 20');
      expect(str(sparkPaginationRange(18, 20, 0))).assertEqual('1 … 18 19 20');
      expect(str(sparkPaginationRange(4, 20, 1))).assertEqual('1 2 3 4 5 … 20');
    });
    it('near_start_and_end', 0, () => {
      expect(str(sparkPaginationRange(1, 20, 1))).assertEqual('1 2 3 4 5 … 20');
      expect(str(sparkPaginationRange(20, 20, 1))).assertEqual('1 … 16 17 18 19 20');
    });
    it('middle', 0, () => {
      expect(str(sparkPaginationRange(10, 20, 1))).assertEqual('1 … 9 10 11 … 20');
      expect(str(sparkPaginationRange(10, 20, 0))).assertEqual('1 … 10 … 20');
      expect(str(sparkPaginationRange(10, 20, 2))).assertEqual('1 … 8 9 10 11 12 … 20');
    });
    it('constant_slot_count', 0, () => {
      for (let s = 0; s <= 2; s++) {
        for (let p = 1; p <= 30; p++) {
          expect(sparkPaginationRange(p, 30, s).length).assertEqual(2 * s + 5);
        }
      }
    });
    it('always_contains_first_last_and_current', 0, () => {
      for (let p = 1; p <= 25; p++) {
        const r = sparkPaginationRange(p, 25, 1);
        expect(r[0]).assertEqual(1);
        expect(r[r.length - 1]).assertEqual(25);
        expect(r.includes(p)).assertTrue();
      }
    });
    it('clamps_page_and_siblings', 0, () => {
      expect(str(sparkPaginationRange(99, 20, 1))).assertEqual('1 … 16 17 18 19 20');
      expect(str(sparkPaginationRange(-3, 20, -1))).assertEqual('1 2 3 … 20');
    });
    it('siblings_from_width', 0, () => {
      // slot 40 vp, chrome 80 vp: 5 slots → 0 siblings, 7 → 1, 9 → 2
      expect(sparkPaginationSiblings(80 + 5 * 40, 80, 40, 2)).assertEqual(0);
      expect(sparkPaginationSiblings(80 + 7 * 40, 80, 40, 2)).assertEqual(1);
      expect(sparkPaginationSiblings(80 + 9 * 40, 80, 40, 2)).assertEqual(2);
      expect(sparkPaginationSiblings(2000, 80, 40, 2)).assertEqual(2);
      expect(sparkPaginationSiblings(100, 80, 40, 2)).assertEqual(0);
    });
  });
}
