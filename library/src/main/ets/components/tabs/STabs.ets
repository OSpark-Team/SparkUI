import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkRowPressModifier } from '../../primitives/SparkPressModifier';
import { SparkItemRect, SparkSelection } from '../../primitives/SparkSelection';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTokenOverride } from '../../theme/tokens/SparkComponentTokens';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SparkTokenReader } from '../../theme/tokens/SparkTokenReader';
import { SparkAnim } from '../../core/SparkAnim';

const KEY: string = 'spark.tabs';

/** Tabs selection; trigger geometry (for the sliding active indicator) lives in SparkSelection. */
@ObservedV2
export class SparkTabsState extends SparkSelection {
}

function resolveTabs(uiContext: UIContext, id: number): SparkTabsState | undefined {
  return SparkContext.resolve<SparkTabsState>(uiContext, id, KEY);
}

/**
 * shadcn-vue `Tabs`: a set of layered sections of content, one shown at a time.
 *
 * ```
 * STabs({ defaultValue: 'account' }) {
 *   STabsList() {
 *     STabsTrigger({ value: 'account', text: 'Account' })
 *     STabsTrigger({ value: 'password', text: 'Password' })
 *   }
 *   STabsContent({ value: 'account' }) { Text('Account settings') }
 *   STabsContent({ value: 'password' }) { Text('Password settings') }
 * }
 * // controlled: STabs({ value: this.tab!! }) { ... }
 * ```
 */
@ComponentV2
export struct STabs {
  /** Controlled active tab (use with `!!`). Leave undefined for uncontrolled. */
  @Param value: string | undefined = undefined;
  @Event $value: (value: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Event onValueChange: (value: string) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkTabsState = new SparkTabsState();

  aboutToAppear(): void {
    this.state.multiple = false;
    this.state.collapsible = false;
    this.state.controlled = this.value !== undefined;
    const initial = this.value ?? this.defaultValue;
    this.state.values = initial.length > 0 ? [initial] : [];
    this.state.emit = (values: string[]) => {
      const v = values.length > 0 ? values[0] : '';
      this.$value(v);
      this.onValueChange(v);
    };
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('value')
  syncValue(): void {
    if (this.value !== undefined) {
      this.state.assign([this.value]);
    }
  }

  build() {
    // no `space`: hidden STabsContent parts must not leave gaps; the active panel adds its own top padding
    Column() {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * Per-instance token overrides of the tab strip (ADR D13), e.g. an underline-free transparent strip:
 * `STabsList({ tokens: { listBackground: 'transparent', indicatorShadow: 'none' } })`.
 * Instance → theme `--tabs-*` → recipe. (Strip height / trigger colours are theme-level: `--tabs-height`,
 * `--tabs-trigger-foreground`, `--tabs-trigger-active-foreground`.)
 */
export interface TabsTokens {
  listBackground?: string;
  listRadius?: number;
  indicatorBackground?: string;
  indicatorBorderColor?: string;
  indicatorBorderWidth?: number;
  indicatorRadius?: number;
  indicatorShadow?: string;
}

/** Resolved strip / indicator style of STabsList. */
export class TabsListStyle {
  height: number = 36;
  padding: number = 3;
  listBackground: string = '#00000000';
  listRadius: number = 10;
  indicatorBackground: string = '#00000000';
  indicatorBorderColor: string = '#00000000';
  indicatorBorderWidth: number = 0;
  indicatorRadius: number = 8;
  indicatorShadow: ShadowOptions = { radius: 0, color: Color.Transparent };
}

/** Strip height (`--tabs-height`, 36) and inner padding (`--tabs-list-padding`, 3): triggers are height − 2·padding. */
export function sparkTabsMetrics(t: SparkTheme): number[] {
  return [t.comp.length('tabs', 'height', 36), t.comp.length('tabs', 'list-padding', 3)];
}

/** shadcn tabs recipe (`bg-muted rounded-lg p-[3px]`, active `bg-background shadow-sm` / dark `bg-input/30 border-input`) → tokens. */
export function sparkTabsListStyle(t: SparkTheme, tokens?: TabsTokens): TabsListStyle {
  const c = t.colors;
  const r = new SparkTokenReader(t, 'tabs');
  const s = new TabsListStyle();
  const m = sparkTabsMetrics(t);
  s.height = m[0];
  s.padding = m[1];
  s.listBackground = r.color('list-background', tokens?.listBackground, c.muted);
  s.listRadius = r.len('list-radius', tokens?.listRadius, t.radiusLg);
  s.indicatorBackground = r.color('indicator-background', tokens?.indicatorBackground,
    t.isDark ? SparkColor.alpha(c.input, 0.3) : c.background);
  s.indicatorBorderColor = r.color('indicator-border-color', tokens?.indicatorBorderColor, c.input);
  s.indicatorBorderWidth = r.len('indicator-border-width', tokens?.indicatorBorderWidth, t.isDark ? t.borderWidth : 0);
  s.indicatorRadius = r.len('indicator-radius', tokens?.indicatorRadius, t.radiusMd);
  s.indicatorShadow = SparkTokenOverride.shadowOptions(r.shadow('indicator-shadow', tokens?.indicatorShadow,
    t.shadows.sm));
  return s;
}

/**
 * The tab strip: `bg-muted text-muted-foreground inline-flex h-9 w-fit rounded-lg p-[3px]`.
 * Responsive: when the triggers are wider than the space the list gets, the strip scrolls horizontally.
 */
@ComponentV2
export struct STabsList {
  /** Per-instance token overrides (instance → theme `--tabs-*` → recipe), see {@link TabsTokens}. */
  @Param tokens: TabsTokens = {};
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Computed
  get look(): TabsListStyle {
    return sparkTabsListStyle(this.theme, this.tokens);
  }
  @Local available: number = 0;
  @Local contentWidth: number = 0;
  @Local ctx: SparkTabsState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveTabs(this.getUIContext(), this.getUniqueId());
    }
  }

  @Computed
  get activeRect(): SparkItemRect | undefined {
    const c = this.ctx;
    if (c === undefined || c.values.length === 0) {
      return undefined;
    }
    return c.rectOf(c.values[0]);
  }

  @Computed
  get overflow(): boolean {
    return this.available > 0 && this.contentWidth > this.available + 0.5;
  }

  @Computed
  get viewportWidth(): Length {
    if (this.available > 0 && this.contentWidth > 0) {
      return Math.min(this.available, this.contentWidth);
    }
    return '100%';
  }

  build() {
    Row() {
      Scroll() {
        Stack({ alignContent: Alignment.TopStart }) {
          // Sliding active indicator: one pill that moves between tabs. Selection never cross-fades two
          // backgrounds (and it is a separate node, so it is never on a pressed-style attribute chain).
          if (this.activeRect !== undefined) {
            Column()
              .width(this.activeRect.w)
              .height(this.look.height - this.look.padding * 2)
              .position({ x: this.activeRect.x, y: this.look.padding })
              .backgroundColor(this.look.indicatorBackground)
              .border({
                width: this.look.indicatorBorderWidth,
                color: this.look.indicatorBorderColor,
                radius: this.look.indicatorRadius
              })
              .shadow(this.look.indicatorShadow)
              .animation(this.ctx?.interacted === true ? SparkAnim.attr(this.theme, 'tabs', 'normal') : { duration: 0 })
          }
          Row() {
            this.content()
          }
          .height(this.look.height)
          .padding(this.look.padding)
          .alignItems(VerticalAlign.Center)
          .onAreaChange((_: Area, n: Area) => {
            this.contentWidth = Number(n.width);
          })
        }
        .backgroundColor(this.look.listBackground)
        .border({ width: 0, radius: this.look.listRadius })
      }
      .width(this.viewportWidth)
      .scrollable(ScrollDirection.Horizontal)
      .enableScrollInteraction(this.overflow)
      .scrollBar(BarState.Off)
      .edgeEffect(this.overflow ? EdgeEffect.Spring : EdgeEffect.None)
      .align(Alignment.Start)
      .border({ width: 0, radius: this.look.listRadius })
      .clip(true)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .accessibilityRole(AccessibilityRoleType.TAB_BAR)
    .onAreaChange((_: Area, n: Area) => {
      this.available = Number(n.width);
    })
  }
}

/**
 * A tab button. `rounded-md px-2 py-1 text-sm font-medium`; active: `bg-background shadow-sm`
 * (dark: `bg-input/30 border-input`). Activates its tab when tapped; the native `.onClick()` on the
 * trigger itself is not needed (use `onValueChange` on STabs).
 */
@ComponentV2
export struct STabsTrigger {
  @Param value: string = '';
  @Param text: ResourceStr | undefined = undefined;
  /** Leading lucide icon name. */
  @Param icon: string | undefined = undefined;
  @Param disabled: boolean = false;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ctx: SparkTabsState | undefined = undefined;
  @Local ix: SparkInteraction = new SparkInteraction();

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveTabs(this.getUIContext(), this.getUniqueId());
    }
  }

  @Computed
  get active(): boolean {
    return this.ctx !== undefined && this.ctx.has(this.value);
  }

  /** The active background is the list's sliding indicator; triggers only show pressed feedback. */
  @Computed
  get press(): SparkRowPressModifier {
    // the sliding indicator shows the selection; pressing a trigger only fades it (no second highlight)
    return new SparkRowPressModifier('#00000000', '#00000000', this.active ? 1 : 0.6, this.disabled);
  }

  @Computed
  get foreground(): string {
    const c = this.theme.colors;
    const comp = this.theme.comp;
    const active = comp.color('tabs', 'trigger-active-foreground', c.foreground);
    if (this.active || this.ix.hovered) {
      return active;
    }
    return comp.color('tabs', 'trigger-foreground', this.theme.isDark ? c.mutedForeground :
      SparkColor.alpha(c.foreground, 0.85));
  }

  @Computed
  get triggerHeight(): number {
    const m = sparkTabsMetrics(this.theme);
    return m[0] - m[1] * 2;
  }

  @Computed
  get triggerRadius(): number {
    return this.theme.comp.length('tabs', 'indicator-radius', this.theme.radiusMd);
  }

  build() {
    Row({ space: 6 }) {
      if (this.icon !== undefined) {
        SIcon({ name: this.icon, sizing: 16, color: this.foreground })
      }
      if (this.text !== undefined) {
        Text(this.text)
          .fontSize(this.theme.text.sm)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.foreground)
          .maxLines(1)
      }
      this.content()
    }
    .height(this.triggerHeight)
    .padding({ left: 8, right: 8 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .attributeModifier(this.press)
    .border({ width: 0, radius: this.triggerRadius })
    .onAreaChange((_: Area, n: Area) => {
      this.ctx?.report(this.value, Number(n.position.x ?? 0), Number(n.position.y ?? 0), Number(n.width),
        Number(n.height));
    })
    .focusable(!this.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilitySelected(this.active)
    .accessibilityText(typeof this.text === 'string' ? this.text : this.value)
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .onClick(() => {
      if (!this.disabled) {
        this.ctx?.select(this.value);
      }
    })
  }
}

/** Panel shown while its `value` is the active tab (fades in). */
@ComponentV2
export struct STabsContent {
  @Param value: string = '';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ctx: SparkTabsState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveTabs(this.getUIContext(), this.getUniqueId());
    }
  }

  @Computed
  get active(): boolean {
    return this.ctx !== undefined && this.ctx.has(this.value);
  }

  build() {
    Column() {
      if (this.active) {
        Column() {
          this.content()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ top: 8 })
        .transition(SparkAnim.enter(this.theme, 'tabs', 'fast', undefined, 4))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .accessibilityRole(AccessibilityRoleType.TAB_CONTENT)
  }
}
