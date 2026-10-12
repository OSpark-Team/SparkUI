import { sparkEmptyBuilder } from '../../core/Builders';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  ToggleSize, ToggleStyle, ToggleStyleModifier, ToggleTokens, ToggleVariant, ToggleVariants
} from './ToggleVariants';

/**
 * shadcn-vue `Toggle`: a two-state button that can be either on or off.
 *
 * ```
 * SToggle({ icon: 'bold', label: 'Toggle bold' })
 * SToggle({ variant: 'outline', icon: 'italic', text: 'Italic', defaultPressed: true })
 * SToggle({ pressed: this.bold!!, icon: 'bold', label: 'Bold' })      // controlled
 * ```
 *
 * The toggle handles taps itself; observe changes with `onPressedChange` (or `!!`). A native `.onClick()` on
 * SToggle does not fire because the inner tap wins.
 */
@ComponentV2
export struct SToggle {
  /** Controlled state (use with `!!`). Leave undefined for uncontrolled. */
  @Param pressed: boolean | undefined = undefined;
  @Event $pressed: (pressed: boolean) => void = () => {
  };
  @Param defaultPressed: boolean = false;
  @Event onPressedChange: (pressed: boolean) => void = () => {
  };
  @Param variant: ToggleVariant = 'default';
  @Param sizing: ToggleSize = 'default';
  @Param text: ResourceStr | undefined = undefined;
  /** Leading lucide icon name. */
  @Param icon: string | undefined = undefined;
  /** Accessible name; required for icon-only toggles. */
  @Param label: string | undefined = undefined;
  @Param disabled: boolean = false;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  /** Per-instance token overrides (instance → theme `--toggle-*` → recipe), see {@link ToggleTokens}. */
  @Param tokens: ToggleTokens = {};
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ix: SparkInteraction = new SparkInteraction();
  @Local current: boolean = false;

  aboutToAppear(): void {
    this.current = this.pressed ?? this.defaultPressed;
    this.ix.enabled = !this.disabled;
  }

  @Monitor('pressed')
  syncPressed(): void {
    if (this.pressed !== undefined) {
      this.current = this.pressed;
    }
  }

  @Monitor('disabled')
  syncEnabled(): void {
    this.ix.enabled = !this.disabled;
    if (this.disabled) {
      this.ix.reset();
    }
  }

  private set(v: boolean): void {
    if (this.pressed === undefined) {
      this.current = v;
    }
    this.$pressed(v);
    this.onPressedChange(v);
  }

  @Computed
  get styles(): ToggleStyle {
    return ToggleVariants.resolve(this.theme, this.variant, this.sizing, this.current, this.ix.hovered, this.tokens);
  }

  @Computed
  get recipe(): ToggleStyleModifier {
    return new ToggleStyleModifier(this.styles, 'none', this.disabled);
  }

  @Computed
  get accessibleName(): string {
    if (this.label !== undefined) {
      return this.label;
    }
    return typeof this.text === 'string' ? this.text : '';
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
    .focusable(!this.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityRole(AccessibilityRoleType.TOGGLER)
    .accessibilityChecked(this.current)
    .accessibilityText(this.accessibleName)
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .onClick(() => {
      if (!this.disabled) {
        this.set(!this.current);
      }
    })
  }
}
