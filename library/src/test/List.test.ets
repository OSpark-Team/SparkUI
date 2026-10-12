import sparkColorTest from './SparkColor.test';
import themeCssTest from './ThemeCss.test';
import iconsTest from './Icons.test';
import placementTest from './Placement.test';
import codeHighlighterTest from './CodeHighlighter.test';
import paginationTest from './Pagination.test';

export default function testsuite() {
  sparkColorTest();
  themeCssTest();
  iconsTest();
  placementTest();
  codeHighlighterTest();
  paginationTest();
}
