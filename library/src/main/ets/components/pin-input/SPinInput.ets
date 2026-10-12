import { sparkTextOf } from '../../core/SparkText';
import { SparkAnim } from '../../core/SparkAnim';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkNoFocusBox } from '../input/SInput';
import {
  PinPattern, sparkPinActiveIndex, sparkPinGroups, sparkPinSanitize, sparkPinSlotSize
} from './PinInputLogic';

/** Blinking fake caret (`animate-caret-blink bg-foreground h-4 w-px`), in its own node so removing it stops it. */
@ComponentV2
struct SparkPinCaret {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local faded: boolean = false;

  @Computed
  get blink(): AnimateParam {
    const p = SparkAnim.attr(this.theme, 'pin-input', 'slow');
    if (p.duration !== undefined && p.duration > 0) {
      // caret-blink is a 1s cycle in shadcn; keep the token's ratio but at least ~0.5s per phase
      p.duration = Math.max(500, p.duration * 2);
      p.iterations = -1;
      p.playMode = PlayMode.Alternate;
    }
    return p;
  }

  build() {
    Column()
      .width(1)
      .height(16)
      .backgroundColor(this.theme.colors.foreground)
      .opacity(this.faded ? 0 : 1)
      .animation(this.blink)
      .onAppear(() => {
        if (SparkAnim.duration(this.theme, 'pin-input', 'slow') > 0) {
          setTimeout(() => {
            this.faded = true;
          }, 0);
        }
      })
  }
}

/**
 * shadcn `InputOTP` look (shadcn-vue `PinInput`): joined `h-9 w-9` slots with a shared border, the active slot
 * gets `border-ring ring-ring/50 ring-[3px]` and a blinking caret.
 *
 * ```
 * SPinInput({ value: this.code!!, onComplete: (v: string) => this.verify(v) })
 * SPinInput({ length: 6, groups: [3, 3] })                 // 123 – 456
 * SPinInput({ length: 4, masked: true, pattern: 'digits' })  // PIN
 * SPinInput({ length: 6, pattern: 'alphanumeric' })
 * ```
 *
 * One transparent TextInput laid over the slots captures typing / paste / backspace (tapping anywhere
 * opens the keyboard); the slots only render the characters. Slots shrink from 36 to 28vp when the
 * component's own width is too small.
 */
@ComponentV2
export struct SPinInput {
  @Param length: number = 6;
  /** Controlled value (use with `!!`). Leave undefined for uncontrolled. */
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Param defaultValue: string = '';
  /** Show `•` instead of the characters (shadcn-vue `mask`; renamed: `mask` is a universal attribute). */
  @Param masked: boolean = false;
  @Param pattern: PinPattern = 'digits';
  /** Slot groups separated by a dash, e.g. [3, 3]; must add up to `length`. */
  @Param groups: number[] | undefined = undefined;
  @Param disabled: boolean = false;
  @Param invalid: boolean = false;
  /** Accessible name. */
  @Param label: ResourceStr = $r('app.string.spark_one_time_code');
  @Event onValueChange: (v: string) => void = () => {
  };
  /** Fired when all slots are filled. */
  @Event onComplete: (v: string) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local current: string = '';
  @Local focused: boolean = false;
  /** text bound to the native field (may briefly hold rejected characters) */
  @Local nativeText: string = '';
  @Local available: number = 0;
  private controller: TextInputController = new TextInputController();

  aboutToAppear(): void {
    this.current = sparkPinSanitize(this.value ?? this.defaultValue, this.pattern, this.length);
    this.nativeText = this.current;
  }

  @Monitor('value')
  syncValue(): void {
    if (this.value !== undefined) {
      this.current = sparkPinSanitize(this.value, this.pattern, this.length);
      this.nativeText = this.current;
    }
  }

  private set(raw: string): void {
    const v = sparkPinSanitize(raw, this.pattern, this.length);
    this.nativeText = raw;
    if (raw !== v) {
      // rejected characters: put the clean text back into the (invisible) native field on the next tick
      setTimeout(() => {
        this.nativeText = v;
        this.controller.caretPosition(v.length);
      }, 0);
    }
    if (v === this.current) {
      return;
    }
    this.current = v;
    this.$value(v);
    this.onValueChange(v);
    if (v.length === this.length) {
      this.onComplete(v);
    }
    this.controller.caretPosition(v.length);
  }

  @Computed
  get groupSizes(): number[] {
    return sparkPinGroups(this.length, this.groups);
  }

  @Computed
  get slot(): number {
    return sparkPinSlotSize(this.available, this.length, this.groupSizes.length);
  }

  @Computed
  get activeIndex(): number {
    return this.focused ? sparkPinActiveIndex(this.current.length, this.length) : -1;
  }

  /** Global slot indexes of group `g`. */
  private slotsOf(g: number): number[] {
    const sizes = this.groupSizes;
    let start = 0;
    for (let i = 0; i < g; i++) {
      start += sizes[i];
    }
    const out: number[] = [];
    for (let i = 0; i < sizes[g]; i++) {
      out.push(start + i);
    }
    return out;
  }

  private charAt(i: number): string {
    if (i >= this.current.length) {
      return '';
    }
    return this.masked ? '•' : this.current.charAt(i);
  }

  private slotBorder(active: boolean): string {
    const c = this.theme.colors;
    if (this.invalid) {
      return c.destructive;
    }
    return active ? c.ring : c.input;
  }

  @Builder
  slotCell(i: number, first: boolean, last: boolean) {
    Stack() {
      Text(this.charAt(i))
        .fontSize(this.theme.text.sm)
        .fontColor(this.theme.colors.foreground)
      if (i === this.activeIndex && i >= this.current.length) {
        SparkPinCaret()
      }
    }
    .width(this.slot)
    .height(36)
    .backgroundColor(this.theme.isDark ? SparkColor.alpha(this.theme.colors.input, 0.3) : '#00000000')
    // border-y border-r, first:border-l, first:rounded-l-md, last:rounded-r-md
    .border({
      width: { left: first || i === this.activeIndex ? 1 : 0, right: 1, top: 1, bottom: 1 },
      color: this.slotBorder(i === this.activeIndex),
      radius: {
        topLeft: first ? this.theme.radiusMd : 0,
        bottomLeft: first ? this.theme.radiusMd : 0,
        topRight: last ? this.theme.radiusMd : 0,
        bottomRight: last ? this.theme.radiusMd : 0
      }
    })
    .outline({
      width: i === this.activeIndex ? 3 : 0,
      color: this.invalid ? SparkColor.alpha(this.theme.colors.destructive, this.theme.isDark ? 0.4 : 0.2) :
        SparkColor.alpha(this.theme.colors.ring, 0.5),
      radius: {
        topLeft: first ? this.theme.radiusMd + 3 : 3,
        bottomLeft: first ? this.theme.radiusMd + 3 : 3,
        topRight: last ? this.theme.radiusMd + 3 : 3,
        bottomRight: last ? this.theme.radiusMd + 3 : 3
      },
      style: OutlineStyle.SOLID
    })
    .margin({ left: !first && i === this.activeIndex ? -1 : 0 })
    .zIndex(i === this.activeIndex ? 1 : 0)
    .shadow(this.theme.shadows.xs.toOptions())
    .animation(SparkAnim.attr(this.theme, 'pin-input', 'fast'))
  }

  build() {
    Row() {
      Stack({ alignContent: Alignment.Start }) {
        Row({ space: 8 }) {
          ForEach(this.groupSizes, (size: number, g: number) => {
            if (g > 0) {
              SIcon({ name: 'minus', sizing: 16, color: this.theme.colors.mutedForeground })
            }
            Row() {
              ForEach(this.slotsOf(g), (i: number, k: number) => {
                this.slotCell(i, k === 0, k === size - 1)
              }, (i: number) => `${i}`)
            }
          }, (size: number, g: number) => `${g}-${size}`)
        }

        // the real input: transparent, laid over the slots so a tap anywhere focuses it
        TextInput({ text: this.nativeText, controller: this.controller })
          .type(this.pattern === 'digits' ? InputType.Number : InputType.Normal)
          .maxLength(this.length)
          .width('100%')
          .height(36)
          .opacity(0)
          .fontColor('#00000000')
          .caretColor('#00000000')
          .backgroundColor('#00000000')
          .selectedBackgroundColor('#00000000')
          .copyOption(CopyOptions.None)
          .enabled(!this.disabled)
          .focusable(!this.disabled)
          .focusBox(sparkNoFocusBox())
          .accessibilityText(sparkTextOf(this.getUIContext(), this.label, 'One-time code'))
          .onChange((v: string) => this.set(v))
          .onFocus(() => {
            this.focused = true;
            this.controller.caretPosition(this.current.length);
          })
          .onBlur(() => {
            this.focused = false;
          })
      }
      .opacity(this.disabled ? 0.5 : 1)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .onAreaChange((_: Area, n: Area) => {
      this.available = Number(n.width);
    })
  }
}
