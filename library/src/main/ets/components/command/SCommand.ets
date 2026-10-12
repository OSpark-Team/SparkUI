import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkTapBlocker } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { OverlayBinding, SparkActivation } from '../../primitives/overlay/OverlayBinding';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure } from '../../primitives/SparkDisclosure';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkNoFocusBox } from '../input/SInput';
import { sparkCommandScore } from './CommandScore';

const KEY: string = 'spark.command';
const GROUP_KEY: string = 'spark.command.group';

const KEY_UP: number = 2012;
const KEY_DOWN: number = 2013;
const KEY_ENTER: number = 2054;
const KEY_NUMPAD_ENTER: number = 2124;
const KEY_HOME: number = 2081;
const KEY_END: number = 2082;

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
 *       SCommandItem({ value: 'calendar', text: 'Calendar', icon: 'calendar' }).onClick(() => ...)
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
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkCommandState = new SparkCommandState();

  aboutToAppear(): void {
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

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.theme.colors.popover)
    .borderRadius(this.theme.radiusMd)
    .clip(true)
    // ↑ / ↓ when focus is elsewhere inside the command (Enter is handled by the input's onSubmit, so that
    // it is not activated twice when the key event bubbles up from the field)
    .onKeyEvent((e: KeyEvent) => {
      this.state.key(e, false);
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
 * highlighted (keyboard ↑/↓ or pointer hover — switches instantly, never cross-fades) or pressed.
 * Activates on tap / click / Enter: fires `onSelect(value)`; the native `.onClick()` on the item also works.
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
  private activation: SparkActivation = new SparkActivation();

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
  get blocker(): SparkTapBlocker {
    return new SparkTapBlocker(this.disabled);
  }

  @Styles
  normalStyle() {
    .backgroundColor(this.highlighted ? this.theme.colors.accent : Color.Transparent)
  }

  @Styles
  pressedStyle() {
    .backgroundColor(this.disabled ? Color.Transparent : this.theme.colors.accent)
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
    .opacity(this.disabled ? 0.5 : 1)
    .visibility(this.shown ? Visibility.Visible : Visibility.None)
    .stateStyles({ normal: this.normalStyle, pressed: this.pressedStyle })
    .onHover((h: boolean) => {
      SparkUI.layout.reportPointerEvent(true);
      if (h && !this.disabled) {
        this.state?.highlight(this.itemValue);
      }
    })
    .gestureModifier(this.blocker)
    .onTouch((e: TouchEvent) => this.activation.touch(e, this.disabled, () => this.select()))
    .focusable(false)
    .accessibilityText(this.plainText)
    .accessibilitySelected(this.highlighted)
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
 * Closes after an item is selected unless `closeOnSelect: false`.
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
          onItemSelect: () => {
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
