import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkAnim } from '../../core/SparkAnim';
import { SparkContext } from '../../core/SparkContext';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkPressModifier } from '../../core/SparkPress';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  sparkStepperHorizontal, StepperItemState, StepperOrientation, sparkStepReachable, sparkStepState
} from './StepperLogic';

const KEY: string = 'spark.stepper';
const CIRCLE: number = 32;

/** Stepper state shared with its items: current step, registered steps and the resolved orientation. */
@ObservedV2
export class SparkStepperState {
  @Trace current: number = 1;
  @Trace horizontal: boolean = true;
  /** registered step numbers, ascending */
  @Trace steps: number[] = [];
  linear: boolean = true;
  controlled: boolean = false;
  emit: (step: number) => void = () => {
  };
  private counts: Map<number, number> = new Map<number, number>();

  register(step: number): void {
    const n = this.counts.get(step) ?? 0;
    this.counts.set(step, n + 1);
    if (n === 0) {
      const next = this.steps.slice();
      next.push(step);
      next.sort((a: number, b: number) => a - b);
      this.steps = next;
    }
  }

  unregister(step: number): void {
    const n = this.counts.get(step) ?? 0;
    if (n <= 1) {
      this.counts.delete(step);
      this.steps = this.steps.filter((s: number) => s !== step);
    } else {
      this.counts.set(step, n - 1);
    }
  }

  isFirst(step: number): boolean {
    return this.steps.length === 0 || step <= this.steps[0];
  }

  isLast(step: number): boolean {
    return this.steps.length === 0 || step >= this.steps[this.steps.length - 1];
  }

  select(step: number): void {
    if (step === this.current) {
      return;
    }
    if (!this.controlled) {
      this.current = step;
    }
    this.emit(step);
  }
}

function resolveStepper(ui: UIContext, id: number): SparkStepperState | undefined {
  return SparkContext.resolve<SparkStepperState>(ui, id, KEY);
}

/**
 * shadcn-vue `Stepper`: numbered steps joined by separators; earlier steps are completed (check), the current
 * one is active, later ones inactive.
 *
 * ```
 * SStepper({ value: this.step!! }) {
 *   SStepperItem({ step: 1, title: 'Address', description: 'Where should we ship?' })
 *   SStepperItem({ step: 2, title: 'Shipping', description: 'Pick a carrier' })
 *   SStepperItem({ step: 3, title: 'Checkout' })
 * }
 * ```
 *
 * Steps are numbers (1-based like reka-ui; `value` is the current step). `orientation: 'responsive'` (default)
 * is horizontal when the stepper's own width gives every step at least 140vp, vertical otherwise.
 * `linear` (default) only lets the user jump back or to the next step; tapping a step selects it.
 */
@ComponentV2
export struct SStepper {
  /** Controlled current step (use with `!!`). Leave undefined for uncontrolled. */
  @Param value: number | undefined = undefined;
  @Event $value: (v: number) => void = () => {
  };
  @Param defaultValue: number = 1;
  @Param orientation: StepperOrientation = 'responsive';
  @Param linear: boolean = true;
  @Event onValueChange: (v: number) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkStepperState = new SparkStepperState();
  @Local measured: number = 0;

  aboutToAppear(): void {
    this.state.current = this.value ?? this.defaultValue;
    this.state.controlled = this.value !== undefined;
    this.state.linear = this.linear;
    this.state.emit = (step: number) => {
      this.$value(step);
      this.onValueChange(step);
    };
    this.layout();
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('value')
  syncValue(): void {
    if (this.value !== undefined) {
      this.state.current = this.value;
    }
  }

  @Monitor('linear')
  syncLinear(): void {
    this.state.linear = this.linear;
  }

  @Monitor('orientation', 'measured', 'state.steps')
  layout(): void {
    const h = sparkStepperHorizontal(this.orientation, this.measured, this.state.steps.length);
    if (h !== this.state.horizontal) {
      this.state.horizontal = h;
    }
  }

  build() {
    Flex({
      direction: this.state.horizontal ? FlexDirection.Row : FlexDirection.Column,
      alignItems: ItemAlign.Start
    }) {
      this.content()
    }
    .width('100%')
    .onAreaChange((_: Area, n: Area) => {
      this.measured = Number(n.width);
    })
  }
}

/**
 * One step: indicator circle (`rounded-full size-8`; check when completed, number otherwise), title
 * (`text-sm font-semibold`), description (`text-xs text-muted-foreground`) and the separator to the next step
 * (`h-0.5 bg-muted`, `bg-primary` once completed). Extra content goes in the slot.
 */
@ComponentV2
export struct SStepperItem {
  @Param step: number = 1;
  @Param title: ResourceStr = '';
  @Param description: ResourceStr | undefined = undefined;
  @Param disabled: boolean = false;
  /** Lucide icon shown in the circle instead of the number (completed steps still show a check). */
  @Param icon: string | undefined = undefined;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ctx: SparkStepperState | undefined = undefined;
  @Local textHeight: number = 0;
  private registered: number | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  aboutToDisappear(): void {
    if (this.ctx !== undefined && this.registered !== undefined) {
      this.ctx.unregister(this.registered);
    }
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = resolveStepper(this.getUIContext(), this.getUniqueId());
      if (this.ctx !== undefined) {
        this.registered = this.step;
        this.ctx.register(this.step);
      }
    }
  }

  @Monitor('step')
  syncStep(): void {
    if (this.ctx !== undefined && this.registered !== undefined && this.registered !== this.step) {
      this.ctx.unregister(this.registered);
      this.registered = this.step;
      this.ctx.register(this.step);
    }
  }

  @Computed
  get itemState(): StepperItemState {
    return sparkStepState(this.step, this.ctx?.current ?? 1);
  }

  @Computed
  get horizontal(): boolean {
    return this.ctx === undefined || this.ctx.horizontal;
  }

  @Computed
  get first(): boolean {
    return this.ctx === undefined || this.ctx.isFirst(this.step);
  }

  @Computed
  get last(): boolean {
    return this.ctx === undefined || this.ctx.isLast(this.step);
  }

  @Computed
  get reachable(): boolean {
    const c = this.ctx;
    return !this.disabled && c !== undefined && sparkStepReachable(this.step, c.current, c.linear);
  }

  @Computed
  get press(): SparkPressModifier {
    return new SparkPressModifier(this.disabled, this.reachable ? 0.7 : 1);
  }

  /** Separator before this step: completed when the previous step is. */
  @Computed
  get lineBefore(): string {
    const cur = this.ctx?.current ?? 1;
    return this.step <= cur ? this.theme.colors.primary : this.theme.colors.muted;
  }

  /** Separator after this step. */
  @Computed
  get lineAfter(): string {
    return this.itemState === 'completed' ? this.theme.colors.primary : this.theme.colors.muted;
  }

  @Computed
  get titleColor(): string {
    return this.itemState === 'inactive' ? this.theme.colors.mutedForeground : this.theme.colors.foreground;
  }

  @Computed
  get accessibleName(): string {
    const t = typeof this.title === 'string' ? this.title : '';
    return `Step ${this.step}: ${t} (${this.itemState})`;
  }

  @Builder
  circle() {
    Stack() {
      if (this.itemState === 'completed') {
        SIcon({ name: 'check', sizing: 16, color: this.theme.colors.primaryForeground, strokeWidth: 2.5 })
          .transition(SparkAnim.enter(this.theme, 'stepper', 'fast', 0.5))
      } else if (this.icon !== undefined) {
        SIcon({
          name: this.icon,
          sizing: 16,
          color: this.itemState === 'active' ? this.theme.colors.primaryForeground : this.theme.colors.mutedForeground
        })
      } else {
        Text(`${this.step}`)
          .fontSize(this.theme.text.sm)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.itemState === 'active' ? this.theme.colors.primaryForeground :
            this.theme.colors.mutedForeground)
      }
    }
    .width(CIRCLE)
    .height(CIRCLE)
    .flexShrink(0)
    .backgroundColor(this.itemState === 'inactive' ? this.theme.colors.background : this.theme.colors.primary)
    .border({
      width: this.itemState === 'inactive' ? 1 : 0,
      color: this.theme.colors.border,
      radius: CIRCLE / 2
    })
    .outline({
      width: this.itemState === 'active' ? 3 : 0,
      color: SparkColor.alpha(this.theme.colors.ring, 0.5),
      radius: CIRCLE / 2 + 3,
      style: OutlineStyle.SOLID
    })
    .animation(SparkAnim.attr(this.theme, 'stepper', 'normal'))
  }

  @Builder
  texts(center: boolean) {
    Text(this.title)
      .fontSize(this.theme.text.sm)
      .fontWeight(this.theme.text.weightSemibold)
      .fontColor(this.titleColor)
      .textAlign(center ? TextAlign.Center : TextAlign.Start)
    if (this.description !== undefined) {
      Text(this.description)
        .fontSize(this.theme.text.xs)
        .lineHeight(this.theme.text.leadingXs)
        .fontColor(this.theme.colors.mutedForeground)
        .textAlign(center ? TextAlign.Center : TextAlign.Start)
    }
    this.content()
  }

  build() {
    Row() {
      if (this.horizontal) {
        Column({ space: 4 }) {
          Row() {
            Column()
              .layoutWeight(1)
              .height(2)
              .margin({ right: 8 })
              .backgroundColor(this.lineBefore)
              .border({ width: 0, radius: 1 })
              .visibility(this.first ? Visibility.Hidden : Visibility.Visible)
              .animation(SparkAnim.attr(this.theme, 'stepper', 'normal'))
            this.circle()
            Column()
              .layoutWeight(1)
              .height(2)
              .margin({ left: 8 })
              .backgroundColor(this.lineAfter)
              .border({ width: 0, radius: 1 })
              .visibility(this.last ? Visibility.Hidden : Visibility.Visible)
              .animation(SparkAnim.attr(this.theme, 'stepper', 'normal'))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: 4 })

          this.texts(true)
        }
        .width('100%')
        .padding({ left: 4, right: 4 })
        .alignItems(HorizontalAlign.Center)
      } else {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            this.circle()
            if (!this.last) {
              Column()
                .width(2)
                .height(Math.max(8, this.textHeight - CIRCLE - 8))
                .backgroundColor(this.lineAfter)
                .border({ width: 0, radius: 1 })
                .animation(SparkAnim.attr(this.theme, 'stepper', 'normal'))
            }
          }
          .alignItems(HorizontalAlign.Center)

          Column({ space: 2 }) {
            this.texts(false)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .padding({ top: 6, bottom: this.last ? 0 : 24 })
          .onAreaChange((_: Area, n: Area) => {
            this.textHeight = Number(n.height);
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
    }
    .width('100%')
    .flexGrow(this.horizontal ? 1 : 0)
    .flexBasis(this.horizontal ? 0 : 'auto')
    .attributeModifier(this.press)
    .focusable(this.reachable)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilitySelected(this.itemState === 'active')
    .accessibilityText(this.accessibleName)
    .onClick(() => {
      if (this.reachable) {
        this.ctx?.select(this.step);
      }
    })
  }
}
