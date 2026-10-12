import { KeyCode } from '@kit.InputKit';
import { SparkInteraction } from '../../core/SparkInteraction';
import { sparkFocusRing, SparkTapBlocker } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkAdaptive, SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { SparkOptionList } from '../../primitives/list/SparkOptionList';
import {
  SparkOptionEntry, sparkOptionEntries, sparkOptionFirst, sparkOptionIndexOf, SparkOptionSource, sparkOptionStep
} from '../../primitives/list/SparkOptionLogic';
import { sparkMenuPanelMaxHeight } from '../../primitives/menu/SparkMenuParts';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTokenOverride } from '../../theme/tokens/SparkComponentTokens';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  sparkOptionPanel, SparkOptionPanelStyle, SparkOptionPanelTokens, sparkSurfaceDefaults
} from '../../theme/tokens/SparkTokenReader';
import { sparkCommandScore } from '../command/CommandScore';
import { sparkUseSheet } from '../dropdown-menu/SDropdownMenu';
import { sparkNoFocusBox } from '../input/SInput';
import { SparkSelectOption } from '../select/SSelect';

/** Options matching `query` (cmdk scoring on the label, the value as a keyword), document order kept. */
export function sparkComboboxEntries(options: SparkOptionSource[], query: string): SparkOptionEntry[] {
  const q = query.trim();
  if (q.length === 0) {
    return sparkOptionEntries(options);
  }
  return sparkOptionEntries(options, (o: SparkOptionSource) => sparkCommandScore(q, o.label, [o.value]) > 0);
}

/**
 * shadcn-vue `Combobox` (Popover + Command): an outline button showing the selected label and a
 * chevrons-up-down icon; opens a searchable list with a check mark on the selected option.
 *
 * ```
 * SCombobox({
 *   value: this.framework!!,
 *   options: FRAMEWORKS,                       // SparkSelectOption[] (shared with SSelect)
 *   placeholder: 'Select framework…',
 *   searchPlaceholder: 'Search framework…',
 *   emptyText: 'No framework found.'
 * })
 * ```
 * Anchored below the trigger (as wide as the trigger, at least 200vp) on pointer / wide screens; a bottom
 * sheet on compact touch screens. Selecting the current option again clears it (shadcn behaviour) unless
 * `deselectable: false`.
 *
 * The results are virtualized (ADR D14: `List` + `Repeat.virtualScroll()`): filtering recomputes the matching
 * rows (O(n) per keystroke, cmdk scoring) and only the visible ones are built — options that do not match are
 * never built at all. ↑ / ↓ move the highlight (the list follows it), Enter picks it.
 *
 * Panel tokens (ADR D13/D14): `--combobox-*` (`background` `border-color` `radius` `border-width` `padding`
 * `shadow` `highlight-background` `highlight-foreground` `max-height`), falling back to the shared `--popover-*`
 * surface; per instance via `tokens`.
 */
@ComponentV2
export struct SCombobox {
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Event onValueChange: (v: string) => void = () => {
  };
  @Param options: SparkSelectOption[] = [];
  @Param placeholder: ResourceStr = 'Select option…';
  @Param searchPlaceholder: ResourceStr = 'Search…';
  @Param emptyText: ResourceStr = 'No results found.';
  /** trigger width (shadcn demo: w-[200px]); '100%' to fill the parent */
  @Param triggerWidth: Length = 200;
  @Param disabled: boolean = false;
  @Param deselectable: boolean = true;
  @Param adaptive: SparkAdaptive = 'auto';
  @Param tokens: SparkOptionPanelTokens = {};
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local current: string = '';
  @Local disclosure: SparkDisclosure = new SparkDisclosure();
  @Local sheet: boolean = false;
  @Local anchorWidth: number = 200;
  @Local ix: SparkInteraction = new SparkInteraction();
  @Local query: string = '';
  @Local highlighted: string = '';
  /** the open overlay scope: its placement gives the height available to the list */
  @Local scope: SparkOverlayScope | undefined = undefined;
  private binding: OverlayBinding = new OverlayBinding();

  aboutToAppear(): void {
    this.current = this.value ?? this.defaultValue;
    this.disclosure.triggerKey = sparkTriggerKey(this.getUniqueId());
    this.disclosure.triggerUniqueId = this.getUniqueId();
    this.binding.attach(this.getUIContext(), this.disclosure, (scope: SparkOverlayScope) => {
      this.scope = scope;
      this.sheet = sparkUseSheet(this.adaptive);
      this.disclosure.placement = this.sheet ? 'sheet' : 'anchored';
      this.query = '';
      this.highlighted = sparkOptionIndexOf(this.entries, this.current) >= 0 ? this.current :
        sparkOptionFirst(this.entries);
      const anchor = this.disclosure.anchorRect(this.getUIContext());
      this.anchorWidth = anchor !== undefined ? anchor.width : 200;
      scope.presentation = this.sheet ? 'sheet-bottom' : 'anchored';
      scope.motionKey = 'popover';
      scope.modal = this.sheet;
      scope.dismissOnOutside = true;
      scope.anchor = anchor;
      scope.side = 'bottom';
      scope.alignment = 'start';
      scope.sideOffset = 4;
      scope.content = this.panel;
      scope.contextKey = '';
      scope.theme = this.theme;
      scope.layout = this.layout;
    });
  }

  aboutToDisappear(): void {
    this.binding.dispose();
  }

  @Monitor('value')
  sync(): void {
    if (this.value !== undefined) {
      this.current = this.value;
    }
  }

  @Computed
  get label(): string | undefined {
    const o = this.options.find((x: SparkSelectOption) => x.value === this.current);
    return o === undefined ? undefined : o.label;
  }

  /** matching rows (headings + options); only the visible ones are built */
  @Computed
  get entries(): SparkOptionEntry[] {
    return sparkComboboxEntries(this.options, this.query);
  }

  @Computed
  get surface(): SparkOptionPanelStyle {
    const t = this.theme;
    return sparkOptionPanel(t, 'combobox', 'popover', sparkSurfaceDefaults(t.colors.popover, t.colors.border,
      t.borderWidth, this.sheet ? t.radiusXl : t.radiusMd, 0, t.shadows.md), this.sheet ? 360 : 300, this.tokens);
  }

  @Computed
  get blocker(): SparkTapBlocker {
    return new SparkTapBlocker(this.disabled);
  }

  private setQuery(q: string): void {
    this.query = q;
    this.highlighted = sparkOptionFirst(this.entries);
  }

  private choose(v: string): void {
    const next = this.deselectable && v === this.current ? '' : v;
    if (this.value === undefined) {
      this.current = next;
    }
    this.$value(next);
    this.onValueChange(next);
    this.disclosure.setOpen(false);
  }

  /** ↑ / ↓ move the highlight (before the IME sees them); true when consumed */
  private onListKey(e: KeyEvent): boolean {
    if (e.keyCode !== KeyCode.KEYCODE_DPAD_UP && e.keyCode !== KeyCode.KEYCODE_DPAD_DOWN) {
      return false;
    }
    if (e.type === KeyType.Down) {
      this.highlighted = sparkOptionStep(this.entries, this.highlighted,
        e.keyCode === KeyCode.KEYCODE_DPAD_UP ? -1 : 1);
    }
    return true;
  }

  /** panel padding / border, search row (36), list padding (8) and sheet handle (16) around the rows (vp) */
  private chrome(): number {
    const s = this.surface;
    const inner = 36 + 8 + s.padding * 2;
    if (this.sheet) {
      return inner + s.borderWidth + 16 + this.layout.env.safeArea.bottom;
    }
    return inner + s.borderWidth * 2;
  }

  /** `max-height` token / instance value, never taller than the space the placement leaves */
  private listMax(): number {
    return Math.min(this.surface.maxHeight, sparkMenuPanelMaxHeight(this.scope, this.sheet, this.chrome()));
  }

  private inputKey(): string {
    return `spark-combobox-input-${this.getUniqueId()}`;
  }

  @Styles
  normalStyle() {
    .backgroundColor(this.ix.hovered && !this.disabled ? this.theme.colors.accent :
      (this.theme.isDark ? SparkColor.alpha(this.theme.colors.input, 0.3) : this.theme.colors.background))
  }

  @Styles
  pressedStyle() {
    .backgroundColor(this.disabled ? this.theme.colors.background : this.theme.colors.accent)
  }

  @LocalBuilder
  panel() {
    Column() {
      if (this.sheet) {
        Row() {
          Column().width(40).height(4).borderRadius(2).backgroundColor(this.theme.colors.muted)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 8, bottom: 4 })
      }
      // CommandInput: `flex h-9 items-center gap-2 border-b px-3`
      Row({ space: 8 }) {
        SIcon({ name: 'search', sizing: 16, color: this.theme.colors.mutedForeground })
          .opacity(0.5)
        TextInput({ text: this.query, placeholder: this.searchPlaceholder })
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
          .defaultFocus(!this.sheet)
          .accessibilityRole(AccessibilityRoleType.SEARCH_FIELD)
          .onChange((v: string) => this.setQuery(v))
          .onSubmit((_: EnterKeyType, ev?: SubmitEvent) => {
            ev?.keepEditableState();
            if (this.highlighted.length > 0) {
              this.choose(this.highlighted);
            }
          })
          .onKeyPreIme((e: KeyEvent): boolean => this.onListKey(e))
      }
      .width('100%')
      .height(36)
      .padding({ left: 12, right: 12 })
      .border({ width: { bottom: this.surface.borderWidth }, color: this.surface.borderColor })

      if (this.entries.length === 0) {
        // CommandEmpty: `py-6 text-center text-sm`
        Text(this.emptyText)
          .width('100%')
          .padding({ top: 24, bottom: 24 })
          .textAlign(TextAlign.Center)
          .fontSize(this.theme.text.sm)
          .fontColor(this.theme.colors.popoverForeground)
      } else {
        Column() {
          SparkOptionList({
            entries: this.entries,
            selected: this.current,
            highlighted: this.highlighted,
            roomy: this.sheet,
            maxListHeight: this.listMax(),
            rowsFocusable: false,
            highlightBackground: this.surface.highlightBackground,
            highlightForeground: this.surface.highlightForeground,
            onPick: (v: string) => this.choose(v),
            onHighlight: (v: string) => {
              this.highlighted = v;
            }
          })
        }
        .width('100%')
        .padding(4)
      }
    }
    // definite width (at least the trigger's): '100%' rows would otherwise resolve against the overlay layer
    .width(this.sheet ? '100%' : Math.max(this.anchorWidth, 200))
    .padding({
      left: this.surface.padding,
      right: this.surface.padding,
      top: this.surface.padding,
      bottom: this.surface.padding + (this.sheet ? this.layout.env.safeArea.bottom : 0)
    })
    .backgroundColor(this.surface.background)
    .border({
      width: this.sheet ? { top: this.surface.borderWidth } : this.surface.borderWidth,
      color: this.surface.borderColor,
      radius: this.sheet ? { topLeft: this.surface.radius, topRight: this.surface.radius } : this.surface.radius
    })
    .clip(true)
    .shadow(SparkTokenOverride.shadowOptions(this.surface.shadow))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    Row({ space: 8 }) {
      Text(this.label ?? this.placeholder)
        .layoutWeight(1)
        .fontSize(this.theme.text.sm)
        .fontWeight(this.theme.text.weightMedium)
        .fontColor(this.theme.colors.foreground)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      SIcon({ name: 'chevrons-up-down', sizing: 16, color: this.theme.colors.foreground })
        .opacity(0.5)
    }
    .id(sparkTriggerKey(this.getUniqueId()))
    .width(this.triggerWidth)
    .height(36)
    .padding({ left: 12, right: 12 })
    .border({
      width: this.theme.borderWidth,
      color: this.theme.isDark ? this.theme.colors.input : this.theme.colors.border,
      radius: this.theme.radiusMd
    })
    .shadow(this.theme.shadows.xs.toOptions())
    .stateStyles({ normal: this.normalStyle, pressed: this.pressedStyle })
    .opacity(this.disabled ? 0.5 : 1)
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .gestureModifier(this.blocker)
    .focusable(!this.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityRole(AccessibilityRoleType.SELECT)
    .accessibilityText(this.label ?? '')
    .onClick(() => {
      if (!this.disabled) {
        this.disclosure.toggle();
      }
    })
  }
}
