import { sparkTextArg } from '../../core/SparkText';
import { KeyCode } from '@kit.InputKit';
import { LengthMetrics } from '@kit.ArkUI';
import { SparkAnim } from '../../core/SparkAnim';
import { SparkContext } from '../../core/SparkContext';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkRowPressModifier } from '../../primitives/SparkPressModifier';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { resolveSparkField, SparkFieldState, sparkFieldGrows } from '../field/SField';
import { InputColors, sparkInputColors, sparkNoFocusBox } from '../input/SInput';
import { sparkTagsAdd, sparkTagsParse, sparkTagsRemoveAt } from './TagsInputLogic';

/** Two deletes closer than this (ms) are one key press seen by both onWillDelete and onKeyEvent. */
const DELETE_DEDUPE_MS: number = 80;

/**
 * shadcn-vue `TagsInput`: chips (`h-5 rounded-md bg-secondary`, text + x) and an inline input in one bordered
 * field (`flex flex-wrap gap-2 items-center rounded-md border px-2 py-1`), with the v4 focus ring.
 *
 * ```
 * STagsInput({ value: this.tags!!, placeholder: 'Add a framework…' })
 * STagsInput({ defaultValue: ['vue', 'react'], max: 5, delimiter: ';' })
 * ```
 *
 * Enter or the delimiter (default `,`) adds the typed text; Backspace in the empty input removes the last
 * tag; the x on a chip removes it. Duplicates are ignored. Chips wrap onto new lines.
 */
@ComponentV2
export struct STagsInput {
  /** Controlled tags (use with `!!`). Leave undefined for uncontrolled. */
  @Param value: string[] | undefined = undefined;
  @Event $value: (v: string[]) => void = () => {
  };
  @Param defaultValue: string[] = [];
  @Param placeholder: ResourceStr = '';
  /** Maximum number of tags (0 = unlimited). */
  @Param max: number = 0;
  @Param delimiter: string = ',';
  @Param allowDuplicates: boolean = false;
  @Param disabled: boolean = false;
  @Param invalid: boolean = false;
  /** Accessible name when there is no visible label. */
  @Param label: string | undefined = undefined;
  @Event onValueChange: (v: string[]) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local tags: string[] = [];
  @Local draft: string = '';
  @Local focused: boolean = false;
  @Local field: SparkFieldState | undefined = undefined;
  private inputKey: string = '';
  private lastDeleteAt: number = 0;

  aboutToAppear(): void {
    this.tags = (this.value ?? this.defaultValue).slice();
    this.inputKey = `spark-tags-input-${this.getUniqueId()}`;
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.field === undefined) {
      this.field = resolveSparkField(this.getUIContext(), this.getUniqueId());
    }
  }

  @Monitor('value')
  syncValue(): void {
    if (this.value !== undefined) {
      this.tags = this.value.slice();
    }
  }

  private emit(next: string[]): void {
    if (next.length === this.tags.length && next.every((t: string, i: number) => t === this.tags[i])) {
      return;
    }
    this.tags = next;
    this.$value(next.slice());
    this.onValueChange(next.slice());
  }

  private onDraft(text: string, commit: boolean): void {
    const parsed = sparkTagsParse(text, this.delimiter, commit);
    if (parsed.tags.length > 0) {
      this.emit(sparkTagsAdd(this.tags, parsed.tags, this.max, this.allowDuplicates));
    }
    this.draft = parsed.rest;
  }

  private removeAt(i: number): void {
    if (!this.disabled) {
      this.emit(sparkTagsRemoveAt(this.tags, i));
    }
  }

  /** Backspace with an empty input removes the last tag. */
  private deleteBackward(): void {
    const now = Date.now();
    if (this.draft.length > 0 || this.tags.length === 0 || now - this.lastDeleteAt < DELETE_DEDUPE_MS) {
      return;
    }
    this.lastDeleteAt = now;
    this.removeAt(this.tags.length - 1);
  }

  @Computed
  get colors(): InputColors {
    const invalid = this.invalid || (this.field !== undefined && this.field.isInvalid);
    return sparkInputColors(this.theme, this.focused && !this.disabled, invalid);
  }

  @Computed
  get removePress(): SparkRowPressModifier {
    return new SparkRowPressModifier('#00000000', SparkColor.alpha(this.theme.colors.foreground, 0.1), 0.7,
      this.disabled);
  }

  @Builder
  chip(tag: string, index: number) {
    Row({ space: 2 }) {
      Text(tag)
        .fontSize(this.theme.text.sm)
        .lineHeight(this.theme.text.leadingSm)
        .fontColor(this.theme.colors.secondaryForeground)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 8, right: 2 })
      Row() {
        SIcon({ name: 'x', sizing: 14, color: this.theme.colors.secondaryForeground })
      }
      .width(18)
      .height(18)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .margin({ right: 2 })
      .attributeModifier(this.removePress)
      .border({ width: 0, radius: this.theme.radiusSm })
      .focusable(!this.disabled)
      .focusBox(sparkFocusRing(this.theme))
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(sparkTextArg(this.getUIContext(), $r('app.string.spark_remove_tag'), `Remove ${tag}`, tag))
      .onClick(() => this.removeAt(index))
    }
    .height(24)
    .constraintSize({ maxWidth: '100%' })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.theme.colors.secondary)
    .border({ width: 0, radius: this.theme.radiusMd })
    .transition(SparkAnim.enter(this.theme, 'tags-input', 'fast', 0.8))
  }

  build() {
    Flex({
      wrap: FlexWrap.Wrap,
      alignItems: ItemAlign.Center,
      space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(6) }
    }) {
      ForEach(this.tags, (tag: string, i: number) => {
        this.chip(tag, i)
      }, (tag: string, i: number) => `${i}:${tag}`)
      TextInput({ text: this.draft, placeholder: this.tags.length === 0 ? this.placeholder : '' })
        .id(this.inputKey)
        .flexGrow(1)
        .flexBasis(80)
        .height(24)
        .padding({ left: 4, right: 4, top: 0, bottom: 0 })
        .fontSize(this.theme.text.sm)
        .fontColor(this.theme.colors.foreground)
        .placeholderColor(this.theme.colors.mutedForeground)
        .placeholderFont({ size: this.theme.text.sm })
        .caretColor(this.theme.colors.foreground)
        .selectedBackgroundColor(SparkColor.alpha(this.theme.colors.primary, 0.25))
        .backgroundColor('#00000000')
        .border({ width: 0, radius: 0 })
        .hoverEffect(HoverEffect.None)
        .enterKeyType(EnterKeyType.Done)
        .enabled(!this.disabled)
        .focusable(!this.disabled)
        .focusBox(sparkNoFocusBox())
        .accessibilityText(this.label ?? '')
        .onChange((v: string) => this.onDraft(v, false))
        .onSubmit((_: EnterKeyType, ev?: SubmitEvent) => {
          ev?.keepEditableState();
          this.onDraft(this.draft, true);
        })
        .onWillDelete((info: DeleteValue): boolean => {
          if (this.draft.length === 0) {
            this.deleteBackward();
            return false;
          }
          return true;
        })
        .onKeyEvent((e: KeyEvent) => {
          if (e.type === KeyType.Down && e.keyCode === KeyCode.KEYCODE_DEL) {
            this.deleteBackward();
          }
        })
        .onFocus(() => {
          this.focused = true;
        })
        .onBlur(() => {
          this.focused = false;
          this.onDraft(this.draft, true);
        })
    }
    .width('100%')
    .layoutWeight(sparkFieldGrows(this.field) ? 1 : 0)
    .constraintSize({ minHeight: 36 })
    .padding({ left: 6, right: 6, top: 5, bottom: 5 })
    .backgroundColor(this.colors.background)
    .border({ width: 1, color: this.colors.borderColor, radius: this.theme.radiusMd })
    .outline({
      width: this.colors.ringWidth,
      color: this.colors.ringColor,
      radius: this.theme.radiusMd + 3,
      style: OutlineStyle.SOLID
    })
    .shadow(this.theme.shadows.xs.toOptions())
    .opacity(this.disabled ? 0.5 : 1)
    .animation(SparkAnim.attr(this.theme, 'input', 'fast'))
    .onClick(() => {
      if (!this.disabled) {
        try {
          this.getUIContext().getFocusController().requestFocus(this.inputKey);
        } catch (e) {
          // not focusable — ignore
        }
      }
    })
  }
}
