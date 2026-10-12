import { sparkText } from '../../core/SparkText';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkNoopModifier, sparkFocusRing, SparkTapBlocker } from '../../core/SparkModifier';
import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkSpin } from '../spinner/SSpinner';
import {
  ButtonSize, ButtonStyle, ButtonStyleModifier, ButtonTokens, ButtonVariant, ButtonVariants, SparkPressFeedback
} from './ButtonVariants';

/** `block`: stretch the button to the full width of its parent (`w-full`). */
class ButtonBlockModifier implements AttributeModifier<ButtonAttribute> {
  block: boolean;

  constructor(block: boolean) {
    this.block = block;
  }

  applyNormalAttribute(instance: ButtonAttribute): void {
    if (this.block) {
      instance.width('100%');
    }
  }
}

/**
 * shadcn-vue `Button`.
 *
 * ```
 * SButton({ text: 'Save' }).onClick(() => this.save())
 * SButton({ variant: 'outline', sizing: 'sm', icon: 'plus', text: 'Add' })
 * SButton({ variant: 'ghost', sizing: 'icon', icon: 'ellipsis', label: 'More' })
 * SButton({ variant: 'secondary' }) { Text('Custom content') }
 * SButton({ text: 'Continue', block: true })                        // full width
 * SButton({ text: 'Save', loading: this.saving, loadingText: 'Saving…' })
 * ```
 *
 * Clicks use the native universal event (`.onClick()` on SButton itself, like Vue's `@click`);
 * while `disabled` / `loading` an inner no-op tap gesture swallows the tap (see SparkTapBlocker).
 */
@ComponentV2
export struct SButton {
  @Param text: ResourceStr | undefined = undefined;
  @Param variant: ButtonVariant = 'default';
  @Param sizing: ButtonSize = 'default';
  @Param disabled: boolean = false;
  /** Shows a spinner and disables the button. */
  @Param loading: boolean = false;
  /** Text shown instead of `text` while `loading`. */
  @Param loadingText: ResourceStr | undefined = undefined;
  /** Full width of the parent (`w-full`). */
  @Param block: boolean = false;
  /** Leading lucide icon name. */
  @Param icon: string | undefined = undefined;
  /** Trailing lucide icon name. */
  @Param iconRight: string | undefined = undefined;
  /** Accessible name; required for icon-only buttons. */
  @Param label: string | undefined = undefined;
  /** Extra styles applied after the variant recipe (wins on conflicts). */
  @Param modifier: AttributeModifier<ButtonAttribute> = new SparkNoopModifier<ButtonAttribute>();
  /**
   * Per-instance token overrides (instance → theme `--button-*` → recipe), e.g.
   * `tokens: { radius: 999, background: 'oklch(0.6 0.2 250)' }`. See ADR D13.
   */
  @Param tokens: ButtonTokens = {};
  /** Press feedback: 'background' (actions, default), 'opacity' (selection items), 'none'. */
  @Param pressFeedback: SparkPressFeedback = 'background';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ix: SparkInteraction = new SparkInteraction();
  @Local spinAngle: number = 0;

  @Computed
  get styles(): ButtonStyle {
    return ButtonVariants.resolve(this.theme, this.variant, this.sizing, this.tokens);
  }

  @Computed
  get recipe(): ButtonStyleModifier {
    const m = new ButtonStyleModifier(this.styles, this.ix.hovered, this.disabled || this.loading,
      this.styles.pressedScale);
    m.feedback = this.pressFeedback;
    return m;
  }

  aboutToAppear(): void {
    this.syncEnabled();
  }

  @Monitor('disabled', 'loading')
  syncEnabled(): void {
    this.ix.enabled = !this.disabled && !this.loading;
    if (!this.ix.enabled) {
      this.ix.reset();
    }
  }

  @Computed
  get blockModifier(): ButtonBlockModifier {
    return new ButtonBlockModifier(this.block);
  }

  @Computed
  get shownText(): ResourceStr | undefined {
    return this.loading && this.loadingText !== undefined ? this.loadingText : this.text;
  }

  @Computed
  get tapBlocker(): SparkTapBlocker {
    return new SparkTapBlocker(this.disabled || this.loading);
  }

  @Computed
  get accessibleName(): string {
    if (this.label !== undefined) {
      return this.label;
    }
    return typeof this.text === 'string' ? this.text : '';
  }

  build() {
    Button() {
      Row({ space: this.styles.gap }) {
        if (this.loading) {
          SIcon({ name: 'loader-circle', sizing: this.styles.iconSize, color: this.styles.foreground })
            .rotate({ angle: this.spinAngle })
            // the icon exists only while loading: removed when loading ends, re-added (and restarted) next time
            .onAppear(() => sparkSpin(this.getUIContext(), this.theme, (a: number) => {
              this.spinAngle = a;
            }))
        } else if (this.icon !== undefined) {
          SIcon({ name: this.icon, sizing: this.styles.iconSize, color: this.styles.foreground })
        }
        if (this.shownText !== undefined) {
          Text(this.shownText)
            .fontSize(this.styles.fontSize)
            .fontWeight(this.styles.fontWeight)
            .fontColor(this.styles.foreground)
            .maxLines(1)
            .decoration({
              type: this.styles.underlineOnHover && this.ix.hovered ? TextDecorationType.Underline :
                TextDecorationType.None,
              color: this.styles.foreground
            })
        }
        this.content()
        if (this.iconRight !== undefined) {
          SIcon({ name: this.iconRight, sizing: this.styles.iconSize, color: this.styles.foreground })
        }
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .attributeModifier(this.recipe)
    .attributeModifier(this.blockModifier)
    .attributeModifier(this.modifier)
    .focusable(!this.disabled && !this.loading)
    .gestureModifier(this.tapBlocker)
    .accessibilityDescription(this.disabled ? sparkText(this.getUIContext(), $r('app.string.spark_state_disabled'), 'disabled') : (this.loading ? sparkText(this.getUIContext(), $r('app.string.spark_state_loading'), 'loading') : ''))
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityText(this.accessibleName)
    .onHover((isHover: boolean) => this.ix.hover(this.getUIContext(), this.theme, isHover))
  }
}
