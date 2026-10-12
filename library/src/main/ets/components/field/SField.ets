import { LengthMetrics } from '@kit.ArkUI';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

const KEY: string = 'spark.field';

/** Field width (vp) from which a `responsive` field puts its label beside the control. */
export const FIELD_RESPONSIVE_MIN_WIDTH: number = 480;

export type FieldOrientation = 'vertical' | 'horizontal' | 'responsive';
export type FieldLegendVariant = 'legend' | 'label';

/**
 * State a field shares with its parts (and with SInput / STextarea / SSlider, which take the remaining width
 * when the field lays out horizontally). SFieldContent publishes a nested state that always stacks vertically
 * and inherits invalid / disabled from its field.
 */
@ObservedV2
export class SparkFieldState {
  @Trace orientation: FieldOrientation = 'responsive';
  /** the field's own measured width (vp) */
  @Trace measuredWidth: number = 0;
  @Trace invalid: boolean = false;
  @Trace disabled: boolean = false;
  /** true when an SFieldContent is a direct part (horizontal fields then align items to the top) */
  @Trace hasContent: boolean = false;
  /** for SFieldContent's nested state: the enclosing field */
  @Trace parent: SparkFieldState | undefined = undefined;
  /** nested state (SFieldContent): never horizontal */
  nested: boolean = false;

  get horizontal(): boolean {
    if (this.nested) {
      return false;
    }
    if (this.orientation === 'horizontal') {
      return true;
    }
    if (this.orientation === 'vertical') {
      return false;
    }
    return this.measuredWidth >= FIELD_RESPONSIVE_MIN_WIDTH;
  }

  get isInvalid(): boolean {
    return this.invalid || (this.parent !== undefined && this.parent.isInvalid);
  }

  get isDisabled(): boolean {
    return this.disabled || (this.parent !== undefined && this.parent.isDisabled);
  }

  measure(width: number): void {
    if (Math.abs(width - this.measuredWidth) >= 0.5) {
      this.measuredWidth = width;
    }
  }
}

/** Nearest enclosing field state (SField or SFieldContent), or undefined. Resolve in `onDidBuild()`. */
export function resolveSparkField(uiContext: UIContext, componentId: number): SparkFieldState | undefined {
  return SparkContext.resolve<SparkFieldState>(uiContext, componentId, KEY);
}

/** True when a control inside this field should take the remaining row width (`layoutWeight(1)`). */
export function sparkFieldGrows(field: SparkFieldState | undefined): boolean {
  return field !== undefined && field.horizontal;
}

/**
 * shadcn-vue `Field`: a label, control, description and error laid out together.
 *
 * - `vertical`: stacked (`flex-col gap-3`).
 * - `horizontal`: in a row (`flex-row items-center gap-3`); SFieldLabel / SFieldContent / text controls share
 *   the free width.
 * - `responsive` (default): measures its own width — beside each other from 480vp, stacked below
 *   (the container-query equivalent of shadcn's `@md/field-group:flex-row`).
 *
 * ```
 * SField() {
 *   SFieldLabel({ text: 'Email' })
 *   SInput({ placeholder: 'm@example.com', value: this.email!! })
 *   SFieldDescription({ text: 'We will never share your email.' })
 * }
 * SField({ orientation: 'horizontal' }) {
 *   SCheckbox({ checked: this.terms!! })
 *   SFieldLabel({ text: 'Accept terms and conditions' })
 * }
 * SField({ invalid: true }) { ...; SFieldError({ text: 'Required' }) }
 * ```
 */
@ComponentV2
export struct SField {
  @Param orientation: FieldOrientation = 'responsive';
  /** Error look: SFieldLabel turns destructive, SInput / STextarea show the invalid border. */
  @Param invalid: boolean = false;
  /** Disabled look for the label (opacity 50%). */
  @Param disabled: boolean = false;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkFieldState = new SparkFieldState();

  aboutToAppear(): void {
    this.sync();
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('orientation', 'invalid', 'disabled')
  sync(): void {
    this.state.orientation = this.orientation;
    this.state.invalid = this.invalid;
    this.state.disabled = this.disabled;
  }

  @Computed
  get crossAlign(): ItemAlign {
    if (!this.state.horizontal) {
      return ItemAlign.Start;
    }
    return this.state.hasContent ? ItemAlign.Start : ItemAlign.Center;
  }

  build() {
    Flex({
      direction: this.state.horizontal ? FlexDirection.Row : FlexDirection.Column,
      alignItems: this.crossAlign,
      space: { main: LengthMetrics.vp(12), cross: LengthMetrics.vp(12) }
    }) {
      this.content()
    }
    .width('100%')
    .onAreaChange((_: Area, n: Area) => this.state.measure(Number(n.width)))
  }
}

/** Label of a field. Turns destructive when the field is invalid; fills the free width in horizontal fields. */
@ComponentV2
export struct SFieldLabel {
  @Param text: ResourceStr = '';
  @Param required: boolean = false;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local field: SparkFieldState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.field === undefined) {
      this.field = resolveSparkField(this.getUIContext(), this.getUniqueId());
    }
  }

  @Computed
  get invalid(): boolean {
    return this.field !== undefined && this.field.isInvalid;
  }

  @Computed
  get disabled(): boolean {
    return this.field !== undefined && this.field.isDisabled;
  }

  build() {
    Row({ space: 2 }) {
      Text(this.text)
        .fontSize(this.theme.text.sm)
        .fontWeight(this.theme.text.weightMedium)
        .lineHeight(this.theme.text.leadingSm)
        .fontColor(this.invalid ? this.theme.colors.destructive : this.theme.colors.foreground)
      if (this.required) {
        Text('*')
          .fontSize(this.theme.text.sm)
          .fontWeight(this.theme.text.weightMedium)
          .lineHeight(this.theme.text.leadingSm)
          .fontColor(this.theme.colors.destructive)
          .accessibilityLevel('no')
      }
    }
    .alignItems(VerticalAlign.Center)
    .layoutWeight(sparkFieldGrows(this.field) ? 1 : 0)
    .opacity(this.disabled ? 0.5 : 1)
  }
}

/** Groups a label and description next to a control (`flex flex-1 flex-col gap-1.5`). */
@ComponentV2
export struct SFieldContent {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkFieldState = new SparkFieldState();
  @Local parentField: SparkFieldState | undefined = undefined;

  aboutToAppear(): void {
    this.state.nested = true;
    this.state.orientation = 'vertical';
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.parentField === undefined) {
      const p = resolveSparkField(this.getUIContext(), this.getUniqueId());
      this.parentField = p;
      if (p !== undefined) {
        this.state.parent = p;
        p.hasContent = true;
      }
    }
  }

  build() {
    Column({ space: 6 }) {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(sparkFieldGrows(this.parentField) ? 1 : 0)
  }
}

/** Helper text (`text-muted-foreground text-sm`). */
@ComponentV2
export struct SFieldDescription {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.sm)
      .lineHeight(this.theme.text.leadingSm)
      .fontColor(this.theme.colors.mutedForeground)
  }
}

/** Validation message (`text-destructive text-sm`). Renders nothing while `text` is empty. */
@ComponentV2
export struct SFieldError {
  @Param text: string = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    if (this.text.length > 0) {
      Text(this.text)
        .fontSize(this.theme.text.sm)
        .lineHeight(this.theme.text.leadingSm)
        .fontColor(this.theme.colors.destructive)
        .accessibilityDescription('error')
    }
  }
}

/** Stack of fields (`flex w-full flex-col gap-7`). */
@ComponentV2
export struct SFieldGroup {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column({ space: 28 }) {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** Semantic group of fields with an optional SFieldLegend (`flex flex-col gap-6`). */
@ComponentV2
export struct SFieldSet {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Column({ space: 24 }) {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** Title of an SFieldSet: `legend` = text-base font-medium, `label` = text-sm font-medium. */
@ComponentV2
export struct SFieldLegend {
  @Param text: ResourceStr = '';
  @Param variant: FieldLegendVariant = 'legend';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.variant === 'label' ? this.theme.text.sm : this.theme.text.base)
      .fontWeight(this.theme.text.weightMedium)
      .fontColor(this.theme.colors.foreground)
      .accessibilityLevel('yes')
  }
}

/** Horizontal rule between field groups. */
@ComponentV2
export struct SFieldSeparator {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Divider()
      .strokeWidth(1)
      .color(this.theme.colors.border)
      .width('100%')
  }
}
