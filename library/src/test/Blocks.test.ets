import { describe, it, expect } from '@ohos/hypium';
import {
  SIDEBAR_WIDTH, SIDEBAR_WIDTH_ICON, SIDEBAR_WIDTH_MOBILE, sparkListDetailWide, sparkListPaneWidth,
  sparkSidebarDockWidth, sparkSidebarIsMobile, sparkSidebarSheetWidth, sparkSupportingWide, sparkTopbarCondensed,
  sparkTopbarHeight, sparkSidebarDefaultPolicy, sparkSidebarRailPolicy, sparkSidebarRowWidth, SparkSidebarLayoutInput,
  SparkSidebarLayoutPolicy, sparkListDetailDefaultPolicy, sparkSupportingDefaultPolicy, SparkSplitInput
} from '../main/ets/blocks/BlocksLogic';

function sidebarInput(width: number): SparkSidebarLayoutInput {
  const i: SparkSidebarLayoutInput = {
    containerWidth: width,
    sidebarWidth: 256,
    railWidth: SIDEBAR_WIDTH_ICON,
    minInsetWidth: 360,
    collapsible: 'icon'
  };
  return i;
}

export default function blocksTest() {
  describe('Blocks', () => {
    it('sidebar_dock_width_expanded', 0, () => {
      expect(sparkSidebarDockWidth(true, 'icon', 'sidebar', SIDEBAR_WIDTH)).assertEqual(256);
      expect(sparkSidebarDockWidth(true, 'offcanvas', 'floating', 300)).assertEqual(300);
    });
    it('sidebar_dock_width_icon_rail', 0, () => {
      expect(sparkSidebarDockWidth(false, 'icon', 'sidebar', SIDEBAR_WIDTH)).assertEqual(SIDEBAR_WIDTH_ICON);
      // floating / inset keep the 8 vp frame on both sides (shadcn 3rem + spacing*4)
      expect(sparkSidebarDockWidth(false, 'icon', 'floating', SIDEBAR_WIDTH)).assertEqual(64);
      expect(sparkSidebarDockWidth(false, 'icon', 'inset', SIDEBAR_WIDTH)).assertEqual(64);
    });
    it('sidebar_dock_width_offcanvas_and_none', 0, () => {
      expect(sparkSidebarDockWidth(false, 'offcanvas', 'sidebar', SIDEBAR_WIDTH)).assertEqual(0);
      expect(sparkSidebarDockWidth(false, 'none', 'sidebar', SIDEBAR_WIDTH)).assertEqual(SIDEBAR_WIDTH);
    });
    it('sidebar_mobile_switch', 0, () => {
      expect(sparkSidebarIsMobile(0, 256, 360, 'icon')).assertFalse();
      expect(sparkSidebarIsMobile(400, 256, 360, 'icon')).assertTrue();
      expect(sparkSidebarIsMobile(615, 256, 360, 'offcanvas')).assertTrue();
      expect(sparkSidebarIsMobile(616, 256, 360, 'offcanvas')).assertFalse();
      // a static sidebar never turns into a sheet (shadcn collapsible="none")
      expect(sparkSidebarIsMobile(320, 256, 360, 'none')).assertFalse();
    });
    it('sidebar_sheet_width', 0, () => {
      expect(sparkSidebarSheetWidth(0, SIDEBAR_WIDTH_MOBILE)).assertEqual(288);
      expect(sparkSidebarSheetWidth(1000, SIDEBAR_WIDTH_MOBILE)).assertEqual(288);
      expect(sparkSidebarSheetWidth(320, SIDEBAR_WIDTH_MOBILE)).assertEqual(272);
    });
    it('list_detail_wide', 0, () => {
      expect(sparkListDetailWide(0, 320, 360)).assertFalse();
      expect(sparkListDetailWide(680, 320, 360)).assertFalse();
      expect(sparkListDetailWide(681, 320, 360)).assertTrue();
    });
    it('list_pane_width', 0, () => {
      expect(sparkListPaneWidth(400, 320, false)).assertEqual(400);
      expect(sparkListPaneWidth(1000, 320, true)).assertEqual(320);
      expect(sparkListPaneWidth(600, 320, true)).assertEqual(270);
    });
    it('supporting_wide', 0, () => {
      expect(sparkSupportingWide(0, 320, 480)).assertFalse();
      expect(sparkSupportingWide(799, 320, 480)).assertFalse();
      expect(sparkSupportingWide(800, 320, 480)).assertTrue();
    });
    it('topbar_condensed', 0, () => {
      expect(sparkTopbarCondensed(0)).assertFalse();
      expect(sparkTopbarCondensed(360)).assertTrue();
      expect(sparkTopbarCondensed(520)).assertFalse();
      expect(sparkTopbarHeight(true)).assertEqual(48);
      expect(sparkTopbarHeight(false)).assertEqual(56);
    });
    it('topbar_condensed_custom_threshold', 0, () => {
      expect(sparkTopbarCondensed(600, 720)).assertTrue();
      expect(sparkTopbarCondensed(720, 720)).assertFalse();
    });
    it('sidebar_default_policy', 0, () => {
      expect(sparkSidebarDefaultPolicy(sidebarInput(0))).assertEqual('docked');
      expect(sparkSidebarDefaultPolicy(sidebarInput(615))).assertEqual('sheet');
      expect(sparkSidebarDefaultPolicy(sidebarInput(616))).assertEqual('docked');
    });
    it('sidebar_rail_policy', 0, () => {
      const p: SparkSidebarLayoutPolicy = sparkSidebarRailPolicy(480);
      expect(p(sidebarInput(0))).assertEqual('docked');
      expect(p(sidebarInput(616))).assertEqual('docked');
      expect(p(sidebarInput(528))).assertEqual('rail');
      expect(p(sidebarInput(527))).assertEqual('sheet');
      const fixed = sidebarInput(300);
      fixed.collapsible = 'none';
      expect(p(fixed)).assertEqual('docked');
    });
    it('sidebar_row_width', 0, () => {
      expect(sparkSidebarRowWidth('sheet', true, 'icon', 'sidebar', 256)).assertEqual(0);
      expect(sparkSidebarRowWidth('rail', true, 'offcanvas', 'sidebar', 256)).assertEqual(48);
      expect(sparkSidebarRowWidth('rail', true, 'icon', 'inset', 256)).assertEqual(64);
      expect(sparkSidebarRowWidth('docked', false, 'offcanvas', 'sidebar', 256)).assertEqual(0);
      expect(sparkSidebarRowWidth('docked', true, 'icon', 'sidebar', 256)).assertEqual(256);
    });
    it('split_default_policies', 0, () => {
      const ld: SparkSplitInput = { containerWidth: 681, paneWidth: 320, minOtherWidth: 360 };
      expect(sparkListDetailDefaultPolicy(ld)).assertTrue();
      ld.containerWidth = 680;
      expect(sparkListDetailDefaultPolicy(ld)).assertFalse();
      const sp: SparkSplitInput = { containerWidth: 800, paneWidth: 320, minOtherWidth: 480 };
      expect(sparkSupportingDefaultPolicy(sp)).assertTrue();
      sp.containerWidth = 0;
      expect(sparkSupportingDefaultPolicy(sp)).assertFalse();
    });
  });
}
