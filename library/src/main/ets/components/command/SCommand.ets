import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { sparkFocusRing } from '../../core/SparkModifier';
import { sparkIsEnterUp } from '../../primitives/menu/MenuRow';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure } from '../../primitives/SparkDisclosure';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkNoFocusBox } from '../input/SInput';
import { sparkCommandScore } from './CommandScore';
import { sparkOptionFirst, sparkOptionStep } from '../../primitives/list/SparkOptionLogic';
import { SparkCommandEntryData, sparkCommandEntries, sparkCommandItemOf, SparkCommandRow } from './CommandData';
import { SparkCommandDataList } from './CommandDataList';

const KEY: string = 'spark.command';
const GROUP_KEY: string = 'spark.command.group';

const KEY_UP: number = 2012;
const KEY_DOWN: number = 2013;
const KEY_ENTER: number = 2054;
// KEYCODE_NUMPAD_ENTER (2119 in the SDK KeyCode table)
const KEY_NUMPAD_ENTER: number = 2119;
const KEY_HOME: number = 2081;
const KEY_END: number = 2082;
/** smallest max height of the data-mode list (vp) */
const SPARK_COMMAND_MIN_LIST: number = 64;

class CommandEntry {
  uid: number;
  value: string;
  text: string;
  keywords: string[];
  disabled: boolean;
  group: number;
  select: () => void;

  constructor(uid: number, value: string, text: string, keywords: string[], disabled: boolean, group: number,
    select: () => void) {
    this.uid = uid;
    this.value = value;
    this.text = text;
    this.keywords = keywords;
    this.disabled = disabled;
    this.group = group;
    this.select = select;
  }
}

/** Group identity, provided by SCommandGroup so items can report which group they belong to. */
class CommandGroupRef {
  id: number;

  constructor(id: number) {
    this.id = id;
  }
}

/**
 * Shared state of one `SCommand`: the search query, the registered items (in document order), the
 * highlighted item (keyboard / hover selection — not a pressed state) and the list scroller.
 */
@ObservedV2
export class SparkCommandState {
  @Trace query: string = '';
  /** value of the highlighted item ('' = none) */
  @Trace highlighted: string = '';
  /** bumped whenever the item registry changes */
  @Trace version: number = 0;
  /** an SCommandInput is present: it keeps focus and drives the highlight (items are then not focusable) */
  @Trace hasInput: boolean = false;
  /** false: never hide items (the developer filters the data) */
  filtering: boolean = true;
  uiContext: UIContext | undefined = undefined;
  scroller: Scroller | undefined = undefined;
  listUid: number = -1;
  emitQuery: (q: string) => void = () => {
  };
  /** called after any item was selected (SCommandDialog / SCombobox close here) */
  afterSelect: (value: string) => void = () => {
  };
  private entries: CommandEntry[] = [];

  /** Whether an item with this text / keywords passes the current query. Reactive (reads `query`). */
  matches(text: string, keywords: string[]): boolean {
    return !this.filtering || sparkCommandScore(this.query, text, keywords) > 0;
  }

  register(e: CommandEntry): void {
    this.entries = this.entries.filter((x: CommandEntry) => x.uid !== e.uid);
    this.entries.push(e);
    // component ids grow in creation order, which is document order for a built list
    this.entries.sort((a: CommandEntry, b: CommandEntry) => a.uid - b.uid);
    this.version++;
    this.ensureHighlight();
  }

  unregister(uid: number): void {
    const before = this.entries.length;
    this.entries = this.entries.filter((x: CommandEntry) => x.uid !== uid);
    if (this.entries.length !== before) {
      this.version++;
    }
  }

  private visibleEntries(): CommandEntry[] {
    return this.entries.filter((e: CommandEntry) => this.matches(e.text, e.keywords));
  }

  /** Number of items matching the query (reactive). */
  get visibleCount(): number {
    return this.version >= 0 ? this.visibleEntries().length : 0;
  }

  /** A group is visible unless it has items and none of them match (reactive). */
  groupVisible(group: number): boolean {
    if (this.version < 0) {
      return true;
    }
    const mine = this.entries.filter((e: CommandEntry) => e.group === group);
    return mine.length === 0 || mine.some((e: CommandEntry) => this.matches(e.text, e.keywords));
  }

  setQuery(q: string): void {
    if (q === this.query) {
      return;
    }
    this.query = q;
    this.emitQuery(q);
    this.highlightFirst();
  }

  highlight(value: string): void {
    if (this.highlighted !== value) {
      this.highlighted = value;
    }
  }

  private selectable(): CommandEntry[] {
    return this.visibleEntries().filter((e: CommandEntry) => !e.disabled);
  }

  highlightFirst(): void {
    const list = this.selectable();
    this.highlight(list.length > 0 ? list[0].value : '');
    this.scrollToHighlighted();
  }

  /** Keep a valid highlight after registry / query changes. */
  ensureHighlight(): void {
    const list = this.selectable();
    if (!list.some((e: CommandEntry) => e.value === this.highlighted)) {
      this.highlight(list.length > 0 ? list[0].value : '');
    }
  }

  /** Move the highlight by `delta` (wrapping), or to the first / last item. */
  move(delta: number, edge?: 'first' | 'last'): void {
    const list = this.selectable();
    if (list.length === 0) {
      return;
    }
    let next = 0;
    if (edge === 'first') {
      next = 0;
    } else if (edge === 'last') {
      next = list.length - 1;
    } else {
      const cur = list.findIndex((e: CommandEntry) => e.value === this.highlighted);
      next = cur < 0 ? (delta > 0 ? 0 : list.length - 1) : (cur + delta + list.length) % list.length;
    }
    this.highlight(list[next].value);
    this.scrollToHighlighted();
  }

  /** Select the highlighted item (Enter). */
  activate(): void {
    const e = this.selectable().find((x: CommandEntry) => x.value === this.highlighted);
    if (e !== undefined) {
      e.select();
    }
  }

  /** Handle ↑ / ↓ / Home / End / Enter; returns true when consumed. */
  key(e: KeyEvent, withEnter: boolean): boolean {
    if (e.type !== KeyType.Down) {
      return e.keyCode === KEY_UP || e.keyCode === KEY_DOWN;
    }
    switch (e.keyCode) {
      case KEY_UP:
        this.move(-1);
        return true;
      case KEY_DOWN:
        this.move(1);
        return true;
      case KEY_HOME:
        if (withEnter) {
          this.move(0, 'first');
          return true;
        }
        return false;
      case KEY_END:
        if (withEnter) {
          this.move(0, 'last');
          return true;
        }
        return false;
      case KEY_ENTER:
      case KEY_NUMPAD_ENTER:
        if (withEnter) {
          this.activate();
          return true;
        }
        return false;
      default:
        return false;
    }
  }

  private scrollToHighlighted(): void {
    const ui = this.uiContext;
    const scroller = this.scroller;
    const e = this.entries.find((x: CommandEntry) => x.value === this.highlighted);
    if (ui === undefined || scroller === undefined || e === undefined || this.listUid < 0) {
      return;
    }
    try {
      const list = ui.getFrameNodeByUniqueId(this.listUid);
      const item = ui.getFrameNodeByUniqueId(e.uid);
      if (list === null || item === null) {
        return;
      }
      const ly = list.getPositionToWindow().y;
      const lh = ui.px2vp(list.getMeasuredSize().height);
      const iy = item.getPositionToWindow().y;
      const ih = ui.px2vp(item.getMeasuredSize().height);
      if (iy < ly + 4) {
        scroller.scrollBy(0, iy - ly - 4);
      } else if (iy + ih > ly + lh - 4) {
        scroller.scrollBy(0, iy + ih - ly - lh + 4);
      }
    } catch (err) {
      // not laid out yet
    }
  }
}

/**
 * shadcn-vue `Command` (cmdk): a searchable, keyboard-navigable list of actions.
 *
 * ```
 * SCommand() {
 *   SCommandInput({ placeholder: 'Type a command or search…' })
 *   SCommandList() {
 *     SCommandEmpty({ text: 'No results found.' })
 *     SCommandGroup({ heading: 'Suggestions' }) {
 *       SCommandItem({ value: 'calendar', text: 'Calendar', icon: 'calendar', onSelect: (v: string) => ... })
 *       SCommandItem({ value: 'emoji', text: 'Search Emoji', icon: 'smile', keywords: ['face'] })
 *     }
 *     SCommandSeparator()
 *     SCommandGroup({ heading: 'Settings' }) {
 *       SCommandItem({ value: 'settings', text: 'Settings', shortcut: '⌘S', onSelect: (v: string) => ... })
 *     }
 *   }
 * }
 * ```
 * Items are matched case-insensitively against the query (prefix, substring, then subsequence — see
 * `sparkCommandScore`); groups with no matching item hide; ↑ / ↓ move the highlight, Enter selects it.
 * Results keep their document order (they are filtered, not re-sorted).
 *
 * **Data mode** (long lists, ADR D14): pass `items` instead of slot content. The command then renders its own
 * search field and a virtualized list (`List` + `Repeat.virtualScroll()`): items that do not match the query are
 * never built, and of the matches only the rows in view are.
 * ```
 * SCommand({
 *   items: [
 *     new SparkCommandEntryData({ value: 'calendar', label: 'Calendar', icon: 'calendar', group: 'Suggestions',
 *       keywords: ['date'] }),
 *     new SparkCommandEntryData({ value: 'profile', label: 'Profile', icon: 'user', group: 'Settings',
 *       shortcut: '⌘P', onSelect: (v: string) => ... }),
 *     ...
 *   ],
 *   placeholder: 'Type a command or search…',
 *   emptyText: 'No results found.',
 *   onItemSelect: (v: string) => ...
 * })
 * ```
 * Consecutive items with the same `group` share a heading. ↑ / ↓ in the field move the highlight (the list
 * scrolls to it), Enter or a tap activates an item (`onSelect` of the item, then `onItemSelect`). Values must
 * be unique. `showInput: false` drops the field (rows then take focus).
 */
@ComponentV2
export struct SCommand {
  /** false: show every item regardless of the query (filter the data yourself via onQueryChange) */
  @Param shouldFilter: boolean = true;
  @Event onQueryChange: (query: string) => void = () => {
  };
  /** fired after any item is selected (with its value) */
  @Event onItemSelect: (value: string) => void = () => {
  };
  /** data mode: the items (virtualized list with a built-in search field); undefined = slot mode */
  @Param items: SparkCommandEntryData[] | undefined = undefined;
  /** data mode: search field placeholder */
  @Param placeholder: ResourceStr = 'Type a command or search…';
  /** data mode: text shown when nothing matches */
  @Param emptyText: ResourceStr = 'No results found.';
  /** data mode: max height of the result list (vp) */
  @Param maxListHeight: number = 300;
  /** data mode: render the search field (false: rows take focus, the developer drives the query) */
  @Param showInput: boolean = true;
  /** data mode: focus the field when the command appears (pointer devices; keeps the keyboard closed on touch) */
  @Param autoFocus: boolean = false;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkCommandState = new SparkCommandState();

  aboutToAppear(): void {
    if (this.items !== undefined) {
      this.state.hasInput = this.showInput;
      this.state.highlighted = sparkOptionFirst(this.dataEntries);
    }
    this.state.filtering = this.shouldFilter;
    this.state.uiContext = this.getUIContext();
    this.state.emitQuery = (q: string) => this.onQueryChange(q);
    this.state.afterSelect = (v: string) => this.onItemSelect(v);
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('shouldFilter')
  syncFilter(): void {
    this.state.filtering = this.shouldFilter;
    this.state.version++;
  }

  // ---------------------------------------------------------------------------------------------- data mode

  /** matching rows (headings + items, document order); only the visible ones are built */
  @Computed
  get dataEntries(): SparkCommandRow[] {
    const items = this.items;
    return items === undefined ? [] : sparkCommandEntries(items, this.state.query, this.shouldFilter);
  }

  /** keep a valid highlight when the data changes */
  @Monitor('items', 'showInput')
  syncItems(): void {
    if (this.items === undefined) {
      return;
    }
    this.state.hasInput = this.showInput;
    if (sparkCommandItemOf(this.dataEntries, this.state.highlighted) === undefined) {
      this.state.highlighted = sparkOptionFirst(this.dataEntries);
    }
  }

  private setDataQuery(q: string): void {
    if (q === this.state.query) {
      return;
    }
    this.state.query = q;
    this.onQueryChange(q);
    this.state.highlighted = sparkOptionFirst(this.dataEntries);
  }

  private pick(value: string): void {
    const item = sparkCommandItemOf(this.dataEntries, value);
    if (item === undefined) {
      return;
    }
    this.state.highlighted = value;
    const cb = item.onSelect;
    if (cb !== undefined) {
      cb(value);
    }
    this.onItemSelect(value);
  }

  /** ↑ / ↓ move the highlight (before the IME sees them); true when consumed */
  private onDataKey(e: KeyEvent): boolean {
    if (e.keyCode !== KEY_UP && e.keyCode !== KEY_DOWN) {
      return false;
    }
    if (e.type === KeyType.Down) {
      this.state.highlighted = sparkOptionStep(this.dataEntries, this.state.highlighted,
        e.keyCode === KEY_UP ? -1 : 1);
    }
    return true;
  }

  private inputKey(): string {
    return `spark-command-input-${this.getUniqueId()}`;
  }

  @Builder
  dataBody() {
    if (this.showInput) {
      Row({ space: 8 }) {
        SIcon({ name: 'search', sizing: 16, color: this.theme.colors.mutedForeground })
          .opacity(0.5)
        TextInput({ text: this.state.query, placeholder: this.placeholder })
          .id(this.inputKey())
          .layoutWeight(1)
          .height(36)
          .padding(0)
          .borderRadius(0)
          .backgroundColor(Color.Transparent)
          .fontSize(this.theme.text.sm)
          .fontColor(this.theme.colors.popoverForeground)
          .placeholderColor(this.theme.colors.mutedForeground)
          .placeholderFont({ size: this.theme.text.sm })
          .caretColor(this.theme.colors.foreground)
          .selectedBackgroundColor(SparkColor.alpha(this.theme.colors.primary, 0.25))
          .enterKeyType(EnterKeyType.Go)
          .hoverEffect(HoverEffect.None)
          .focusBox(sparkNoFocusBox())
          .defaultFocus(this.autoFocus)
          .accessibilityRole(AccessibilityRoleType.SEARCH_FIELD)
          .onChange((v: string) => this.setDataQuery(v))
          .onSubmit((_: EnterKeyType, ev?: SubmitEvent) => {
            ev?.keepEditableState();
            this.pick(this.state.highlighted);
          })
          .onKeyPreIme((e: KeyEvent): boolean => this.onDataKey(e))
      }
      .width('100%')
      .height(36)
      .padding({ left: 12, right: 12 })
      .border({ width: { bottom: 1 }, color: this.theme.colors.border })
    }
    if (this.dataEntries.length === 0) {
      // CommandEmpty: `py-6 text-center text-sm`
      Text(this.emptyText)
        .width('100%')
        .padding({ top: 24, bottom: 24 })
        .textAlign(TextAlign.Center)
        .fontSize(this.theme.text.sm)
        .fontColor(this.theme.colors.popoverForeground)
    } else {
      Column() {
        SparkCommandDataList({
          entries: this.dataEntries,
          highlighted: this.state.highlighted,
          // the list padding (p-1) counts towards the max height
          maxListHeight: Math.max(SPARK_COMMAND_MIN_LIST, this.maxListHeight - 8),
          rowsFocusable: !this.showInput,
          onPick: (v: string) => this.pick(v),
          onHighlight: (v: string) => {
            this.state.highlighted = v;
          }
        })
      }
      .width('100%')
      .padding(4)
    }
  }

  build() {
    Column() {
      if (this.items !== undefined) {
        this.dataBody()
      } else {
        this.content()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.colors.popover)
    .borderRadius(this.theme.radiusMd)
    .clip(true)
    // ↑ / ↓ when focus is elsewhere inside the command (Enter is handled by the input's onSubmit, so that
    // it is not activated twice when the key event bubbles up from the field)
    .onKeyEvent((e: KeyEvent) => {
      // without an input the items are focusable and the focused item is the highlight; the data mode's
      // field handles its own keys before the IME
      if (this.state.hasInput && this.items === undefined) {
        this.state.key(e, false);
      }
    })
  }
}

/** `flex h-9 items-center gap-2 border-b px-3` with a search icon and a borderless input. */
@ComponentV2
export struct SCommandInput {
  @Param placeholder: ResourceStr = 'Type a command or search…';
  /** focus the field when it appears (pointer devices; avoid on touch to keep the keyboard closed) */
  @Param autoFocus: boolean = false;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkCommandState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.state === undefined) {
      this.state = SparkContext.resolve<SparkCommandState>(this.getUIContext(), this.getUniqueId(), KEY);
      if (this.state !== undefined) {
        this.state.hasInput = true;
      }
    }
  }

  aboutToDisappear(): void {
    if (this.state !== undefined) {
      this.state.hasInput = false;
    }
  }

  private inputKey(): string {
    return `spark-command-input-${this.getUniqueId()}`;
  }

  build() {
    Row({ space: 8 }) {
      SIcon({ name: 'search', sizing: 16, color: this.theme.colors.mutedForeground })
        .opacity(0.5)
      TextInput({ text: this.state?.query ?? '', placeholder: this.placeholder })
        .id(this.inputKey())
        .layoutWeight(1)
        .height(36)
        .padding(0)
        .borderRadius(0)
        .backgroundColor(Color.Transparent)
        .fontSize(this.theme.text.sm)
        .fontColor(this.theme.colors.popoverForeground)
        .placeholderColor(this.theme.colors.mutedForeground)
        .placeholderFont({ size: this.theme.text.sm })
        .caretColor(this.theme.colors.foreground)
        .selectedBackgroundColor(SparkColor.alpha(this.theme.colors.primary, 0.25))
        .enterKeyType(EnterKeyType.Go)
        .hoverEffect(HoverEffect.None)
        .focusBox(sparkNoFocusBox())
        .defaultFocus(this.autoFocus)
        .onChange((v: string) => this.state?.setQuery(v))
        .onSubmit((_: EnterKeyType, ev?: SubmitEvent) => {
          ev?.keepEditableState();
          this.state?.activate();
        })
        .onKeyPreIme((e: KeyEvent): boolean => {
          const s = this.state;
          return s !== undefined && s.key(e, false);
        })
        .onAppear(() => {
          if (this.autoFocus) {
            setTimeout(() => {
              try {
                this.getUIContext().getFocusController().requestFocus(this.inputKey());
              } catch (e) {
                // detached
              }
            }, 0);
          }
        })
    }
    .width('100%')
    .height(36)
    .padding({ left: 12, right: 12 })
    .border({ width: { bottom: 1 }, color: this.theme.colors.border })
  }
}

/** Scrollable result list: `max-h-[300px] overflow-y-auto`. */
@ComponentV2
export struct SCommandList {
  /** max height before scrolling (vp) */
  @Param maxListHeight: number = 300;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkCommandState | undefined = undefined;
  private scroller: Scroller = new Scroller();

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.state === undefined) {
      const s = SparkContext.resolve<SparkCommandState>(this.getUIContext(), this.getUniqueId(), KEY);
      this.state = s;
      if (s !== undefined) {
        s.scroller = this.scroller;
        s.listUid = this.getUniqueId();
      }
    }
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        this.content()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ maxHeight: this.maxListHeight })
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.None)
    .align(Alignment.Top)
  }
}

/** Shown when the query matches no item: `py-6 text-center text-sm`. */
@ComponentV2
export struct SCommandEmpty {
  @Param text: ResourceStr = 'No results found.';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkCommandState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.state === undefined) {
      this.state = SparkContext.resolve<SparkCommandState>(this.getUIContext(), this.getUniqueId(), KEY);
    }
  }

  @Computed
  get shown(): boolean {
    const s = this.state;
    return s !== undefined && s.query.trim().length > 0 && s.visibleCount === 0;
  }

  build() {
    Column() {
      Text(this.text)
        .fontSize(this.theme.text.sm)
        .fontColor(this.theme.colors.popoverForeground)
        .textAlign(TextAlign.Center)
      this.content()
    }
    .width('100%')
    .padding({ top: 24, bottom: 24 })
    .visibility(this.shown ? Visibility.Visible : Visibility.None)
  }
}

/** `overflow-hidden p-1` with an optional heading `px-2 py-1.5 text-xs font-medium text-muted-foreground`. */
@ComponentV2
export struct SCommandGroup {
  @Param heading: ResourceStr | undefined = undefined;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkCommandState | undefined = undefined;

  aboutToAppear(): void {
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), GROUP_KEY, new CommandGroupRef(this.getUniqueId()));
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.state === undefined) {
      this.state = SparkContext.resolve<SparkCommandState>(this.getUIContext(), this.getUniqueId(), KEY);
    }
  }

  @Computed
  get shown(): boolean {
    const s = this.state;
    return s === undefined || s.groupVisible(this.getUniqueId());
  }

  build() {
    Column() {
      if (this.heading !== undefined) {
        Text(this.heading)
          .width('100%')
          .padding({ left: 8, right: 8, top: 6, bottom: 6 })
          .fontSize(this.theme.text.xs)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.theme.colors.mutedForeground)
      }
      this.content()
    }
    .width('100%')
    .padding(4)
    .alignItems(HorizontalAlign.Start)
    .visibility(this.shown ? Visibility.Visible : Visibility.None)
  }
}

/** `-mx-1 h-px bg-border`; hidden while searching. */
@ComponentV2
export struct SCommandSeparator {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkCommandState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.state === undefined) {
      this.state = SparkContext.resolve<SparkCommandState>(this.getUIContext(), this.getUniqueId(), KEY);
    }
  }

  build() {
    Column()
      .width('100%')
      .height(1)
      .backgroundColor(this.theme.colors.border)
      .visibility(this.state !== undefined && this.state.query.trim().length > 0 ? Visibility.None :
        Visibility.Visible)
  }
}

/**
 * One result row: `relative flex items-center gap-2 rounded-sm px-2 py-1.5 text-sm`, accent background when
 * highlighted (keyboard ↑/↓ or pointer hover — switches instantly, never cross-fades); a press only fades the row
 * (a selection row: a pressed background next to the highlighted one would read as two highlights).
 * Activation is the row's native onClick — tap, click, the screen reader, Space — plus Enter in the input (or on
 * the focused row when the command has no input); it fires `onSelect(value)`. A `.onClick()` chained on the item
 * does not fire (the row's own click takes it).
 */
@ComponentV2
export struct SCommandItem {
  @Param value: string = '';
  @Param text: ResourceStr = '';
  @Param icon: string | undefined = undefined;
  @Param shortcut: string | undefined = undefined;
  /** extra search terms */
  @Param keywords: string[] = [];
  @Param disabled: boolean = false;
  /** undefined: no check slot; true / false: trailing check mark shown / reserved (Combobox) */
  @Param checked: boolean | undefined = undefined;
  @Event onSelect: (value: string) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkCommandState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.state === undefined) {
      const s = SparkContext.resolve<SparkCommandState>(this.getUIContext(), this.getUniqueId(), KEY);
      const g = SparkContext.resolve<CommandGroupRef>(this.getUIContext(), this.getUniqueId(), GROUP_KEY);
      this.state = s;
      this.register(g === undefined ? -1 : g.id);
    }
  }

  private group: number = -1;

  private register(group: number): void {
    this.group = group;
    this.state?.register(new CommandEntry(this.getUniqueId(), this.itemValue, this.plainText, this.keywords,
      this.disabled, group, () => this.select()));
  }

  @Monitor('value', 'text', 'keywords', 'disabled')
  reRegister(): void {
    if (this.state !== undefined) {
      this.register(this.group);
    }
  }

  aboutToDisappear(): void {
    this.state?.unregister(this.getUniqueId());
  }

  private get plainText(): string {
    return typeof this.text === 'string' ? this.text : this.value;
  }

  /** value used for highlight / selection; defaults to the text */
  private get itemValue(): string {
    return this.value.length > 0 ? this.value : this.plainText;
  }

  private select(): void {
    if (this.disabled) {
      return;
    }
    this.onSelect(this.itemValue);
    this.state?.afterSelect(this.itemValue);
  }

  @Computed
  get shown(): boolean {
    const s = this.state;
    return s === undefined || s.matches(this.plainText, this.keywords);
  }

  @Computed
  get highlighted(): boolean {
    const s = this.state;
    return s !== undefined && !this.disabled && s.highlighted === this.itemValue;
  }

  @Computed
  get focusableRow(): boolean {
    const s = this.state;
    return s !== undefined && !s.hasInput && !this.disabled;
  }

  @Styles
  normalStyle() {
    .backgroundColor(this.highlighted ? this.theme.colors.accent : Color.Transparent)
    .opacity(this.disabled ? 0.5 : 1)
  }

  @Styles
  pressedStyle() {
    .backgroundColor(this.highlighted ? this.theme.colors.accent : Color.Transparent)
    .opacity(this.disabled ? 0.5 : 0.6)
  }

  build() {
    Row({ space: 8 }) {
      if (this.icon !== undefined) {
        SIcon({ name: this.icon, sizing: 16, color: this.theme.colors.mutedForeground })
      }
      Text(this.text)
        .layoutWeight(1)
        .fontSize(this.theme.text.sm)
        .fontColor(this.highlighted ? this.theme.colors.accentForeground : this.theme.colors.popoverForeground)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.shortcut !== undefined) {
        Text(this.shortcut)
          .fontSize(this.theme.text.xs)
          .fontColor(this.theme.colors.mutedForeground)
          .letterSpacing(1.5)
      }
      if (this.checked !== undefined) {
        SIcon({ name: 'check', sizing: 16, color: this.theme.colors.popoverForeground })
          .opacity(this.checked ? 1 : 0)
      }
    }
    .width('100%')
    .height(32)
    .padding({ left: 8, right: 8 })
    .borderRadius(this.theme.radiusSm)
    .visibility(this.shown ? Visibility.Visible : Visibility.None)
    .stateStyles({ normal: this.normalStyle, pressed: this.pressedStyle })
    .onHover((h: boolean) => {
      SparkUI.layout.reportPointerEvent(true);
      if (h && !this.disabled) {
        this.state?.highlight(this.itemValue);
      }
    })
    .onClick(() => this.select())
    // with an input, focus stays in it (↑ / ↓ move the highlight, Enter selects); without one, rows take focus
    .focusable(this.focusableRow)
    .focusBox(sparkFocusRing(this.theme))
    .onFocus(() => this.state?.highlight(this.itemValue))
    .onKeyEvent((e: KeyEvent) => {
      if (sparkIsEnterUp(e)) {
        this.select();
      }
    })
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.OPTION)
    .accessibilityText(this.plainText)
    .accessibilityDescription(this.disabled ? 'disabled' : '')
    .accessibilitySelected(this.checked !== undefined ? this.checked : this.highlighted)
  }
}

/**
 * shadcn-vue `CommandDialog`: a Command palette in a centred dialog (`p-0 overflow-hidden`).
 *
 * ```
 * SCommandDialog({ open: this.paletteOpen!! }) {
 *   SCommandInput({ placeholder: 'Type a command or search…' })
 *   SCommandList() { ... }
 * }
 * ```
 * Closes after an item is selected unless `closeOnSelect: false`. Long palettes use the data mode:
 * `SCommandDialog({ open: this.palette!!, items: COMMANDS, autoFocus: true, onItemSelect: ... })`.
 */
@ComponentV2
export struct SCommandDialog {
  @Param open: boolean | undefined = undefined;
  @Event $open: (open: boolean) => void = () => {
  };
  @Param defaultOpen: boolean = false;
  @Event onOpenChange: (open: boolean) => void = () => {
  };
  @Param closeOnSelect: boolean = true;
  @Param shouldFilter: boolean = true;
  /** accessible title (shadcn renders it sr-only) */
  @Param title: string = 'Command Palette';
  /** data mode (see SCommand): items of a virtualized palette instead of slot content */
  @Param items: SparkCommandEntryData[] | undefined = undefined;
  @Param placeholder: ResourceStr = 'Type a command or search…';
  @Param emptyText: ResourceStr = 'No results found.';
  @Param maxListHeight: number = 300;
  /** data mode: focus the search field on open (pointer devices) */
  @Param autoFocus: boolean = false;
  /** fired after any item is selected (with its value) */
  @Event onItemSelect: (value: string) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local state: SparkDisclosure = new SparkDisclosure();
  private binding: OverlayBinding = new OverlayBinding();

  aboutToAppear(): void {
    this.state.controlled = this.open !== undefined;
    this.state.open = this.open ?? this.defaultOpen;
    this.state.emit = (v: boolean) => {
      this.$open(v);
      this.onOpenChange(v);
    };
    this.binding.attach(this.getUIContext(), this.state, (scope: SparkOverlayScope) => {
      scope.presentation = 'center';
      scope.motionKey = 'dialog';
      scope.modal = true;
      scope.dismissOnOutside = true;
      scope.content = this.panel;
      scope.contextKey = '';
      scope.theme = this.theme;
      scope.layout = this.layout;
    });
  }

  aboutToDisappear(): void {
    this.binding.dispose();
  }

  @Monitor('open')
  syncOpen(): void {
    if (this.open !== undefined) {
      this.state.assign(this.open);
    }
  }

  @LocalBuilder
  panel() {
    Column() {
      Column() {
        SCommand({
          shouldFilter: this.shouldFilter,
          items: this.items,
          placeholder: this.placeholder,
          emptyText: this.emptyText,
          maxListHeight: this.maxListHeight,
          autoFocus: this.autoFocus,
          onItemSelect: (v: string) => {
            this.onItemSelect(v);
            if (this.closeOnSelect) {
              this.state.setOpen(false);
            }
          }
        }) {
          this.content()
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: 512 })
      .backgroundColor(this.theme.colors.popover)
      .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg })
      .shadow(this.theme.shadows.lg.toOptions())
      .accessibilityText(this.title)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  build() {
    Column()
      .width(0)
      .height(0)
  }
}
