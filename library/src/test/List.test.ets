import sparkColorTest from './SparkColor.test';
import themeCssTest from './ThemeCss.test';
import iconsTest from './Icons.test';
import placementTest from './Placement.test';
import codeHighlighterTest from './CodeHighlighter.test';
import paginationTest from './Pagination.test';
import dateTest from './Date.test';
import dataTest from './Data.test';
import commandTest from './Command.test';
import blocksTest from './Blocks.test';
import chartTest from './Chart.test';
import variantsTest from './Variants.test';
import transitionTest from './Transition.test';
import virtualListTest from './VirtualList.test';
import colorPickerTest from './ColorPicker.test';

export default function testsuite() {
  sparkColorTest();
  themeCssTest();
  iconsTest();
  placementTest();
  codeHighlighterTest();
  paginationTest();
  dateTest();
  dataTest();
  commandTest();
  blocksTest();
  chartTest();
  variantsTest();
  transitionTest();
  virtualListTest();
  colorPickerTest();
}
