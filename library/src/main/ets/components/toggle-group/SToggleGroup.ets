import { LengthMetrics } from '@kit.ArkUI';
import { SparkAnim } from '../../core/SparkAnim';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkItemRect, SparkSelection } from '../../primitives/SparkSelection';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  ToggleJoin, ToggleSize, ToggleStyle, ToggleStyleModifier, ToggleVariant, ToggleVariants
} from '../toggle/ToggleVariants';

const KEY: string = 'spark.toggle-group';

export type ToggleGroupType = 'single' | 'multiple';

/** Selection plus the group-wide look that items inherit. */
@ObservedV2
export class SparkToggleGroupState extends SparkSelection {
  @Trace variant: ToggleVariant = 'default';
  @Trace sizing: ToggleSize = 'default';
  @Trace disabled: boolean = false;
  /** gap between items; > 0 detaches the items (each keeps its own corners / border) */
  @Trace spacing: number = 0;
  /** single selection drawn by one sliding indicator instead of per-item backgrounds */
  @Trace indicator: boolean = false;
  private joins: Map<string, ToggleJoin> = new Map<string, ToggleJoin>();

  setJoin(value: string, join: ToggleJoin): void {
    this.joins.set(value, join);
  }

  joinOf(value: string): ToggleJoin {
    return this.joins.get(value) ?? 'none';
  }
}

/**
 * shadcn-vue `ToggleGroup`: a set of two-state buttons joined into one control.
 *
 * ```
 * SToggleGroup({ type: 'multiple', variant: 'outline' }) {
 *   SToggleGroupItem({ value: 'bold', icon: 'bold', label: 'Toggle bold' })
 *   SToggleGroupItem({ value: 'italic', icon: 'italic', label: 'Toggle italic' })
 *   SToggleGroupItem({ value: 'underline', icon: 'underline', label: 'Toggle underline' })
 * }
 * // controlled: SToggleGroup({ type: 'single', value: this.align!! }) { ... }
 * // detached chips that wrap: SToggleGroup({ type: 'single', spacing: 8, wrap: true }) { ... }
 * ```
 *
 * `value` is always a string array (for `type: 'single'` it holds at most one entry; tapping the selected
 * item again clears it, like Radix). In `single` mode the selection is one indicator that slides between
 * items (motion key `toggle-group`), so a selection change never flashes or cross-fades two items.
 */
@ComponentV2
export struct SToggleGroup {
  @Param type: ToggleGroupType = 'single';
  /** Controlled pressed items (use with `!!`). Leave undefined for uncontrolled. */
  @Param value: string[] | undefined = undefined;
  @Event $value: (value: string[]) => void = () => {
  };
  @Param defaultValue: string[] = [];
  @Event onValueChange: (value: string[]) => void = () => {
  };
  @Param variant: ToggleVariant = 'default';
  @Param sizing: ToggleSize = 'default';
  @Param disabled: boolean = false;
  /** Gap between items in vp (shadcn `spacing`). 0 = joined segments. */
  @Param spacing: number = 0;
  /** Wrap items onto several lines when they do not fit (use with `spacing`). */
  @Param wrap: boolean = false;
  /** `single` only: tapping the selected item again clears the selection (Radix default: true). */
  @Param deselectable: boolean = true;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkToggleGroupState = new SparkToggleGroupState();

  aboutToAppear(): void {
    this.syncLook();
    this.state.controlled = this.value !== undefined;
    this.state.values = (this.value ?? this.defaultValue).slice();
    this.state.emit = (values: string[]) => {
      this.$value(values);
      this.onValueChange(values);
    };
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('type', 'variant', 'sizing', 'disabled', 'spacing', 'deselectable')
  syncLook(): void {
    this.state.multiple = this.type === 'multiple';
    this.state.collapsible = this.type === 'multiple' || this.deselectable;
    this.state.variant = this.variant;
    this.state.sizing = this.sizing;
    this.state.disabled = this.disabled;
    this.state.spacing = this.spacing;
    this.state.indicator = this.type === 'single';
  }

  @Monitor('value')
  syncValue(): void {
    if (this.value !== undefined) {
      this.state.assign(this.value);
    }
  }

  @Computed
  get activeRect(): SparkItemRect | undefined {
    const s = this.state;
    if (!s.indicator || s.values.length === 0) {
      return undefined;
    }
    return s.rectOf(s.values[0]);
  }

  @Computed
  get indicatorRadius(): BorderRadiuses {
    const s = this.state;
    if (s.geoVersion < 0) {
      // geoVersion: joins are recorded together with the item rectangles
      return ToggleVariants.radii(this.theme.radiusMd, 'none');
    }
    return ToggleVariants.radii(this.theme.radiusMd, s.values.length > 0 ? s.joinOf(s.values[0]) : 'none');
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // The sliding selection: one node whose position / size animate, never on a pressed-style chain.
      if (this.activeRect !== undefined) {
        Column()
          .position({ x: this.activeRect.x, y: this.activeRect.y })
          .width(this.activeRect.w)
          .height(this.activeRect.h)
          .backgroundColor(this.theme.colors.accent)
          .borderRadius(this.indicatorRadius)
          .animation(this.state.interacted ? SparkAnim.attr(this.theme, 'toggle-group', 'normal') :
            { duration: 0 })
      }
      if (this.wrap) {
        Flex({
          wrap: FlexWrap.Wrap,
          alignItems: ItemAlign.Center,
          space: { main: LengthMetrics.vp(this.spacing), cross: LengthMetrics.vp(this.spacing) }
        }) {
          this.content()
        }
      } else {
        Row({ space: this.spacing }) {
          this.content()
        }
        .alignItems(VerticalAlign.Center)
      }
    }
    .border({ width: 0, radius: this.theme.radiusMd })
    .shadow(this.variant === 'outline' && this.spacing === 0 ? this.theme.shadows.xs.toOptions() :
      { radius: 0, color: Color.Transparent })
    .accessibilityGroup(false)
  }
}

/** One item of a toggle group; inherits variant / sizing from the group. */
@ComponentV2
export struct SToggleGroupItem {
  @Param value: string = '';
  @Param text: ResourceStr | undefined = undefined;
  /** Leading lucide icon name. */
  @Param icon: string | undefined = undefined;
  /** Accessible name; required for icon-only items. */
  @Param label: string | undefined = undefined;
  @Param disabled: boolean = false;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ctx: SparkToggleGroupState | undefined = undefined;
  @Local ix: SparkInteraction = new SparkInteraction();

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      const ctx = SparkContext.resolve<SparkToggleGroupState>(this.getUIContext(), this.getUniqueId(), KEY);
      if (ctx !== undefined) {
        ctx.register(this.getUniqueId());
        this.ctx = ctx;
      }
    }
  }

  aboutToDisappear(): void {
    this.ctx?.unregister(this.getUniqueId());
  }

  @Computed
  get on(): boolean {
    return this.ctx !== undefined && this.ctx.has(this.value);
  }

  @Computed
  get inactive(): boolean {
    return this.disabled || (this.ctx !== undefined && this.ctx.disabled);
  }

  @Computed
  get join(): ToggleJoin {
    const ctx = this.ctx;
    if (ctx === undefined) {
      return 'middle';
    }
    if (ctx.spacing > 0) {
      return 'none';
    }
    const id = this.getUniqueId();
    const first = ctx.isFirst(id);
    const last = ctx.isLast(id);
    if (first && last) {
      return 'only';
    }
    return first ? 'first' : (last ? 'last' : 'middle');
  }

  /** The group's sliding indicator paints the selected background. */
  @Computed
  get usesIndicator(): boolean {
    return this.ctx !== undefined && this.ctx.indicator;
  }

  @Computed
  get styles(): ToggleStyle {
    const variant: ToggleVariant = this.ctx?.variant ?? 'default';
    const sizing: ToggleSize = this.ctx?.sizing ?? 'default';
    const s = ToggleVariants.resolve(this.theme, variant, sizing, this.on, this.ix.hovered && !this.inactive);
    if (this.on && this.usesIndicator) {
      s.background = '#00000000';
    }
    return s;
  }

  @Computed
  get recipe(): ToggleStyleModifier {
    return new ToggleStyleModifier(this.styles, this.join, this.inactive);
  }

  @Computed
  get accessibleName(): string {
    if (this.label !== undefined) {
      return this.label;
    }
    return typeof this.text === 'string' ? this.text : this.value;
  }

  build() {
    Row({ space: this.styles.gap }) {
      if (this.icon !== undefined) {
        SIcon({ name: this.icon, sizing: this.styles.iconSize, color: this.styles.foreground })
      }
      if (this.text !== undefined) {
        Text(this.text)
          .fontSize(this.styles.fontSize)
          .fontWeight(this.styles.fontWeight)
          .fontColor(this.styles.foreground)
          .maxLines(1)
          .animation(this.ctx?.interacted === true ? SparkAnim.attr(this.theme, 'toggle-group', 'normal') :
            { duration: 0 })
      }
      this.content()
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .attributeModifier(this.recipe)
    .onAreaChange((_: Area, n: Area) => {
      this.ctx?.setJoin(this.value, this.join);
      this.ctx?.report(this.value, Number(n.position.x ?? 0), Number(n.position.y ?? 0), Number(n.width),
        Number(n.height));
    })
    .focusable(!this.inactive)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityRole(AccessibilityRoleType.TOGGLER)
    .accessibilityChecked(this.on)
    .accessibilityText(this.accessibleName)
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .onClick(() => {
      if (!this.inactive) {
        this.ctx?.toggle(this.value);
      }
    })
  }
}
