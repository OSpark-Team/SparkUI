import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkSelection } from '../../primitives/SparkSelection';
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
 * ```
 *
 * `value` is always a string array (for `type: 'single'` it holds at most one entry; tapping the selected
 * item again clears it, like Radix).
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

  @Monitor('type', 'variant', 'sizing', 'disabled')
  syncLook(): void {
    this.state.multiple = this.type === 'multiple';
    this.state.collapsible = true;
    this.state.variant = this.variant;
    this.state.sizing = this.sizing;
    this.state.disabled = this.disabled;
  }

  @Monitor('value')
  syncValue(): void {
    if (this.value !== undefined) {
      this.state.assign(this.value);
    }
  }

  build() {
    Row() {
      this.content()
    }
    .alignItems(VerticalAlign.Center)
    .border({ width: 0, radius: this.theme.radiusMd })
    .shadow(this.variant === 'outline' ? this.theme.shadows.xs.toOptions() : { radius: 0, color: Color.Transparent })
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
    const id = this.getUniqueId();
    const first = ctx.isFirst(id);
    const last = ctx.isLast(id);
    if (first && last) {
      return 'only';
    }
    return first ? 'first' : (last ? 'last' : 'middle');
  }

  @Computed
  get styles(): ToggleStyle {
    const variant: ToggleVariant = this.ctx?.variant ?? 'default';
    const sizing: ToggleSize = this.ctx?.sizing ?? 'default';
    return ToggleVariants.resolve(this.theme, variant, sizing, this.on, this.ix.hovered && !this.inactive);
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
      }
      this.content()
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .attributeModifier(this.recipe)
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
