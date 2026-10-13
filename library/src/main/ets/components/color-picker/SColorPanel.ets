import { LengthMetrics } from '@kit.ArkUI';
import { sparkEmptyBuilder } from '../../core/Builders';
import { sparkText, sparkTextArg, sparkTextArgs2 } from '../../core/SparkText';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SButton } from '../button/SButton';
import { ButtonSize } from '../button/ButtonVariants';
import { InputColors, InputSize, sparkInputColors, sparkInputHeightOf, sparkNoFocusBox } from '../input/SInput';
import {
  ColorPickerFormat, sparkColorClamp, sparkColorFormatLabel, sparkColorValueToArgb, sparkFormatHsva, SparkHsva,
  sparkHsvaToArgb, sparkHueStops, sparkNextColorFormat, sparkParseColor, sparkRgbToHsv, sparkSameColor,
  SPARK_DEFAULT_SWATCHES
} from './ColorPickerLogic';
import { ColorPickerStyle, ColorPickerTokens, sparkColorPickerStyle } from './ColorPickerStyle';
import { SparkColorArea, SparkColorChip, SparkColorRecents, SparkColorSwatch, SparkColorTrack } from './ColorPickerParts';

/** Most recent colours kept / shown by default. */
const RECENT_LIMIT: number = 10;

/**
 * Inline colour panel: a saturation / brightness area, a hue slider, an optional alpha slider (over a
 * checkerboard), a preview swatch, a colour input, optional format toggle, preset swatches and recent colours.
 * The body of {@link SColorPicker}'s popover; usable on its own.
 *
 * ```
 * SColorPanel({ value: this.color!! })                                         // '#3b82f6'
 * SColorPanel({ defaultValue: '#22c55e', alpha: true, format: 'rgb', onValueCommit: (v: string) => ... })
 * SColorPanel({ value: this.color!!, swatches: [], formatToggle: true, recent: true })
 * SColorPanel({ value: this.color!! }) { SButton({ text: 'Apply', block: true }) }   // trailing footer
 * ```
 * - `value` / `$value` / `defaultValue`: a colour string in the `format` of the panel ('hex' default →
 *   `#rrggbb`, `#rrggbbaa` with `alpha` when translucent; 'rgb' | 'hsl' | 'oklch' → CSS functions). Any CSS
 *   colour SparkColor understands is accepted as input. Hex is CSS order: use `SparkColor.parse(v).value` (or
 *   `sparkColorValueToArgb`) for an ArkUI `#AARRGGBB` colour.
 * - `onValueChange` fires live while dragging; `onValueCommit` once per interaction (release, tap, key, swatch,
 *   Enter / blur of the input).
 * - The input accepts `#RGB` / `#RRGGBB` / `#RRGGBBAA` (and the other CSS forms); invalid text shows the error
 *   look and is reverted on blur. `formatToggle` adds a HEX / RGB / HSL / OKLCH button that only changes what
 *   the input displays.
 * - `swatches` (default: a shadcn-like palette; `[]` hides them), `recent` (recently committed colours, shared
 *   app-wide, see `SparkColorRecents`).
 * - Keyboard: arrows move the area thumb (saturation ←→, brightness ↑↓) and step the hue / alpha sliders.
 * - The trailing closure renders below the panel (e.g. actions).
 */
@ComponentV2
export struct SColorPanel {
  /** Controlled value (use with `!!`). Leave undefined for uncontrolled. */
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  /** Uncontrolled initial value. */
  @Param defaultValue: string = '#000000';
  /** Format of emitted values. */
  @Param format: ColorPickerFormat = 'hex';
  /** Show the alpha slider and keep alpha in values. */
  @Param alpha: boolean = false;
  @Param disabled: boolean = false;
  /** Size of the colour input / format button. */
  @Param sizing: InputSize = 'default';
  /** Show the colour input row. */
  @Param showInput: boolean = true;
  /** HEX / RGB / HSL / OKLCH button that cycles the input's display format. */
  @Param formatToggle: boolean = false;
  /** Preset swatches (any CSS colours); `[]` hides the row. */
  @Param swatches: string[] = SPARK_DEFAULT_SWATCHES;
  /** Show recently committed colours (shared by all panels). */
  @Param recent: boolean = false;
  /** Panel width; undefined → `--color-picker-width` / 240vp. Pass '100%' to fill. */
  @Param panelWidth: Length | undefined = undefined;
  /** Accessible name prefix of the panel's controls. */
  @Param label: string | undefined = undefined;
  /** Per-instance token overrides (instance → theme `--color-picker-*` → recipe), see {@link ColorPickerTokens}. */
  @Param tokens: ColorPickerTokens = {};
  /** Live, while dragging. */
  @Event onValueChange: (v: string) => void = () => {
  };
  /** Once an interaction ends (release, tap, key, swatch, input Enter / blur). */
  @Event onValueCommit: (v: string) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local hue: number = 0;
  @Local sat: number = 0;
  @Local bright: number = 0;
  @Local alphaValue: number = 1;
  @Local display: ColorPickerFormat = 'hex';
  @Local editing: boolean = false;
  @Local editText: string = '';
  @Local editInvalid: boolean = false;
  @Local recents: SparkColorRecents = SparkColorRecents.shared;
  /** last value emitted (echoes of it through `value` are ignored, so the hue never jumps) */
  private lastEmitted: string = '';
  /** last value reported through onValueCommit */
  private lastCommitted: string = '';

  aboutToAppear(): void {
    this.display = this.format;
    this.load(this.value ?? this.defaultValue);
    this.lastEmitted = this.currentValue();
    this.lastCommitted = this.lastEmitted;
  }

  @Monitor('value')
  syncValue(): void {
    const v = this.value;
    if (v === undefined || v === this.lastEmitted || sparkSameColor(v, this.lastEmitted)) {
      return;
    }
    if (this.load(v)) {
      this.lastEmitted = this.currentValue();
      this.lastCommitted = this.lastEmitted;
    }
  }

  @Monitor('format')
  syncFormat(): void {
    this.display = this.format;
  }

  /** Take over a colour string; false when it does not parse. */
  private load(text: string): boolean {
    const c = sparkParseColor(text);
    if (c === undefined) {
      return false;
    }
    const hsv = sparkRgbToHsv(c, this.hue, this.sat);
    this.hue = hsv.h;
    this.sat = hsv.s;
    this.bright = hsv.v;
    this.alphaValue = hsv.a;
    return true;
  }

  private hsva(): SparkHsva {
    return new SparkHsva(this.hue, this.sat, this.bright, this.alpha ? this.alphaValue : 1);
  }

  private currentValue(): string {
    return sparkFormatHsva(this.hsva(), this.format, this.alpha);
  }

  private emit(): void {
    const v = this.currentValue();
    if (v === this.lastEmitted) {
      return;
    }
    this.lastEmitted = v;
    this.$value(v);
    this.onValueChange(v);
  }

  private commit(): void {
    const v = this.currentValue();
    if (this.recent) {
      this.recents.push(v, RECENT_LIMIT);
    }
    if (v === this.lastCommitted) {
      return;
    }
    this.lastCommitted = v;
    this.onValueCommit(v);
  }

  private pickColor(text: string): void {
    if (this.disabled || !this.load(text)) {
      return;
    }
    this.emit();
    this.commit();
  }

  @Computed
  get styles(): ColorPickerStyle {
    return sparkColorPickerStyle(this.theme, this.tokens);
  }

  /** current colour, `#AARRGGBB` (alpha included when on) */
  @Computed
  get argb(): string {
    return sparkHsvaToArgb(new SparkHsva(this.hue, this.sat, this.bright, this.alphaValue), this.alpha);
  }

  @Computed
  get opaque(): string {
    return sparkHsvaToArgb(new SparkHsva(this.hue, this.sat, this.bright, 1), false);
  }

  @Computed
  get hueStops(): string[] {
    return sparkHueStops();
  }

  @Computed
  get alphaStops(): string[] {
    return [SparkColor.alpha(this.opaque, 0), this.opaque];
  }

  @Computed
  get displayText(): string {
    return sparkFormatHsva(new SparkHsva(this.hue, this.sat, this.bright, this.alpha ? this.alphaValue : 1),
      this.display, this.alpha);
  }

  @Computed
  get inputColors(): InputColors {
    return sparkInputColors(this.theme, this.editing && !this.disabled, this.editInvalid);
  }

  @Computed
  get inputHeight(): number {
    return sparkInputHeightOf(this.theme, this.sizing);
  }

  @Computed
  get buttonSize(): ButtonSize {
    return this.sizing === 'sm' ? 'sm' : (this.sizing === 'lg' ? 'lg' : 'default');
  }

  @Computed
  get previewSize(): number {
    const row = Math.max(this.styles.thumbSize, this.styles.trackHeight);
    return this.alpha ? row * 2 + 8 : Math.max(row + 12, 28);
  }

  @Computed
  get areaText(): string {
    const s = Math.round(this.sat * 100);
    const v = Math.round(this.bright * 100);
    return sparkTextArgs2(this.getUIContext(), $r('app.string.spark_color_sv_value'),
      `saturation ${s}, brightness ${v}`, s, v);
  }

  private name(res: Resource, fallback: string): string {
    const n = sparkText(this.getUIContext(), res, fallback);
    return this.label !== undefined && this.label.length > 0 ? `${this.label} ${n}` : n;
  }

  private swatchLabel(v: string): string {
    return sparkTextArg(this.getUIContext(), $r('app.string.spark_color_swatch'), `Color ${v}`, v);
  }

  private isCurrent(v: string): boolean {
    return sparkColorValueToArgb(v, '') === this.argb;
  }

  private onInput(text: string): void {
    this.editText = text;
    const c = sparkParseColor(text);
    this.editInvalid = c === undefined && text.trim().length > 0;
    if (c !== undefined && this.load(text)) {
      this.emit();
    }
  }

  private endEdit(): void {
    this.editInvalid = false;
    this.editText = this.displayText;
    this.commit();
  }

  build() {
    Column({ space: this.styles.gap }) {
      SparkColorArea({
        hue: this.hue,
        sat: this.sat,
        bright: this.bright,
        style: this.styles,
        disabled: this.disabled,
        label: this.name($r('app.string.spark_color_area'), 'Saturation and brightness'),
        valueText: this.areaText,
        onPick: (s: number, v: number) => {
          this.sat = s;
          this.bright = v;
          this.emit();
        },
        onCommit: () => this.commit()
      })

      Row({ space: 12 }) {
        Column({ space: 8 }) {
          SparkColorTrack({
            ratio: sparkColorClamp(this.hue / 360, 0, 1),
            stops: this.hueStops,
            thumbColor: sparkHsvaToArgb(new SparkHsva(this.hue, 1, 1, 1), false),
            style: this.styles,
            disabled: this.disabled,
            label: this.name($r('app.string.spark_color_hue'), 'Hue'),
            valueText: `${Math.round(this.hue)}°`,
            keyStep: 1 / 360,
            onPick: (r: number) => {
              this.hue = r * 360;
              this.emit();
            },
            onCommit: () => this.commit()
          })
          if (this.alpha) {
            SparkColorTrack({
              ratio: this.alphaValue,
              stops: this.alphaStops,
              checker: true,
              thumbColor: this.argb,
              style: this.styles,
              disabled: this.disabled,
              label: this.name($r('app.string.spark_color_alpha'), 'Opacity'),
              valueText: `${Math.round(this.alphaValue * 100)}%`,
              onPick: (r: number) => {
                this.alphaValue = r;
                this.emit();
              },
              onCommit: () => this.commit()
            })
          }
        }
        .layoutWeight(1)

        SparkColorChip({
          argb: this.argb,
          chipWidth: this.previewSize,
          chipHeight: this.previewSize,
          radius: this.styles.radius,
          style: this.styles
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.showInput) {
        Row({ space: 8 }) {
          if (this.formatToggle) {
            Stack() {
              SButton({
                text: sparkColorFormatLabel(this.display),
                variant: 'outline',
                sizing: this.buttonSize,
                disabled: this.disabled,
                label: sparkTextArg(this.getUIContext(), $r('app.string.spark_color_format'),
                  `Color format: ${sparkColorFormatLabel(this.display)}`, sparkColorFormatLabel(this.display))
              })
            }
            .onClick(() => {
              if (!this.disabled) {
                this.display = sparkNextColorFormat(this.display);
                if (this.editing) {
                  this.editText = this.displayText;
                  this.editInvalid = false;
                }
              }
            })
          }
          TextInput({ text: this.editing ? this.editText : this.displayText })
            .layoutWeight(1)
            .height(this.inputHeight)
            .padding({ left: this.inputColors.paddingX, right: this.inputColors.paddingX, top: 0, bottom: 0 })
            .fontSize(this.sizing === 'lg' ? this.theme.text.base : this.theme.text.sm)
            .fontColor(this.inputColors.foreground)
            .fontFeature('"tnum" on')
            .caretColor(this.inputColors.foreground)
            .selectedBackgroundColor(SparkColor.alpha(this.theme.colors.primary, 0.25))
            .backgroundColor(this.inputColors.background)
            .border({
              width: this.inputColors.borderWidth,
              color: this.inputColors.borderColor,
              radius: this.inputColors.radius
            })
            .outline({
              width: this.inputColors.ringWidth,
              color: this.inputColors.ringColor,
              radius: this.inputColors.radius + this.inputColors.ringWidth,
              style: OutlineStyle.SOLID
            })
            .maxLength(48)
            .hoverEffect(HoverEffect.None)
            .enabled(!this.disabled)
            .focusable(!this.disabled)
            .focusBox(sparkNoFocusBox())
            .accessibilityText(this.name($r('app.string.spark_color_value'), 'Color value'))
            .onChange((v: string) => {
              if (this.editing) {
                this.onInput(v);
              }
            })
            .onSubmit(() => this.endEdit())
            .onFocus(() => {
              this.editText = this.displayText;
              this.editInvalid = false;
              this.editing = true;
            })
            .onBlur(() => {
              this.editing = false;
              this.endEdit();
            })
        }
        .width('100%')
      }

      if (this.swatches.length > 0) {
        Flex({
          wrap: FlexWrap.Wrap,
          space: { main: LengthMetrics.vp(this.styles.swatchGap), cross: LengthMetrics.vp(this.styles.swatchGap) }
        }) {
          ForEach(this.swatches, (v: string) => {
            SparkColorSwatch({
              argb: sparkColorValueToArgb(v, '#00000000'),
              selected: this.isCurrent(v),
              style: this.styles,
              disabled: this.disabled,
              label: this.swatchLabel(v),
              onPick: () => this.pickColor(v)
            })
          }, (v: string, i: number) => `${i}:${v}`)
        }
        .width('100%')
        // room for the selected ring (drawn outside the swatch) at the edges
        .padding(4)
      }

      if (this.recent && this.recents.items.length > 0) {
        Column({ space: 6 }) {
          Text($r('app.string.spark_color_recent'))
            .fontSize(this.theme.text.xs)
            .fontWeight(this.theme.text.weightMedium)
            .fontColor(this.theme.colors.mutedForeground)
          Flex({
            wrap: FlexWrap.Wrap,
            space: { main: LengthMetrics.vp(this.styles.swatchGap), cross: LengthMetrics.vp(this.styles.swatchGap) }
          }) {
            ForEach(this.recents.items, (v: string) => {
              SparkColorSwatch({
                argb: sparkColorValueToArgb(v, '#00000000'),
                selected: this.isCurrent(v),
                style: this.styles,
                disabled: this.disabled,
                label: this.swatchLabel(v),
                onPick: () => this.pickColor(v)
              })
            }, (v: string) => v)
          }
          .width('100%')
          .padding(4)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      this.content()
    }
    .width(this.panelWidth ?? this.styles.width)
    .alignItems(HorizontalAlign.Start)
    .opacity(this.disabled ? 0.5 : 1)
  }
}
