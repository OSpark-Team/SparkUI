import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

const KEY: string = 'spark.button-group';

export type ButtonGroupOrientation = 'horizontal' | 'vertical';

/** Orientation + measured cross size, shared with separators. */
@ObservedV2
export class SparkButtonGroupState {
  @Trace orientation: ButtonGroupOrientation = 'horizontal';
  /** height (horizontal) or width (vertical) of the group in vp */
  @Trace crossSize: number = 0;
}

/**
 * shadcn-vue `ButtonGroup`: buttons visually joined into one control.
 *
 * ```
 * SButtonGroup() {
 *   SButton({ variant: 'ghost', text: 'Archive' })
 *   SButtonGroupSeparator()
 *   SButton({ variant: 'ghost', text: 'Report' })
 *   SButtonGroupSeparator()
 *   SButton({ variant: 'ghost', sizing: 'icon', icon: 'ellipsis', label: 'More' })
 * }
 * ```
 *
 * Limitations: ArkUI cannot restyle the children of a slot, so the group cannot strip the inner corners /
 * borders of each SButton the way shadcn's `[&>*:not(:first-child)]:rounded-l-none` does. Instead the group
 * removes the gaps, clips its children to one rounded shape and (when `outlined`) draws the shared outline
 * and shadow itself. Use `ghost` (or borderless) buttons inside an outlined group and place
 * SButtonGroupSeparator between them; `outline` buttons would show doubled borders.
 */
@ComponentV2
export struct SButtonGroup {
  @Param orientation: ButtonGroupOrientation = 'horizontal';
  /** Draw the shared `border shadow-xs` outline (like a group of outline buttons). */
  @Param outlined: boolean = true;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkButtonGroupState = new SparkButtonGroupState();

  aboutToAppear(): void {
    this.state.orientation = this.orientation;
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('orientation')
  syncOrientation(): void {
    this.state.orientation = this.orientation;
  }

  @Computed
  get edgeColor(): string {
    if (!this.outlined) {
      return '#00000000';
    }
    return this.theme.isDark ? this.theme.colors.input : this.theme.colors.border;
  }

  @Computed
  get fill(): string {
    if (!this.outlined) {
      return '#00000000';
    }
    return this.theme.isDark ? SparkColor.alpha(this.theme.colors.input, 0.3) : this.theme.colors.background;
  }

  build() {
    if (this.orientation === 'vertical') {
      Column() {
        this.content()
      }
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.fill)
      .border({ width: this.outlined ? 1 : 0, color: this.edgeColor, radius: this.theme.radiusMd })
      .shadow(this.outlined ? this.theme.shadows.xs.toOptions() : { radius: 0, color: Color.Transparent })
      .clip(true)
      .onAreaChange((_: Area, n: Area) => {
        this.state.crossSize = Number(n.width) - (this.outlined ? 2 : 0);
      })
    } else {
      Row() {
        this.content()
      }
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.fill)
      .border({ width: this.outlined ? 1 : 0, color: this.edgeColor, radius: this.theme.radiusMd })
      .shadow(this.outlined ? this.theme.shadows.xs.toOptions() : { radius: 0, color: Color.Transparent })
      .clip(true)
      .onAreaChange((_: Area, n: Area) => {
        this.state.crossSize = Number(n.height) - (this.outlined ? 2 : 0);
      })
    }
  }
}

/** A 1vp divider between grouped buttons (`bg-input`), spanning the group's cross axis. */
@ComponentV2
export struct SButtonGroupSeparator {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ctx: SparkButtonGroupState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = SparkContext.resolve<SparkButtonGroupState>(this.getUIContext(), this.getUniqueId(), KEY);
    }
  }

  @Computed
  get span(): number {
    const s = this.ctx?.crossSize ?? 0;
    // 0 until measured: the group size then comes from the buttons alone (no feedback loop)
    return Math.max(0, s);
  }

  build() {
    if (this.ctx?.orientation === 'vertical') {
      Column()
        .width(this.span)
        .height(1)
        .backgroundColor(this.theme.isDark ? this.theme.colors.input : this.theme.colors.border)
    } else {
      Column()
        .width(1)
        .height(this.span)
        .backgroundColor(this.theme.isDark ? this.theme.colors.input : this.theme.colors.border)
    }
  }
}
