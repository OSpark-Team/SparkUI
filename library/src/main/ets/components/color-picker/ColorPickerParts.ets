import { KeyCode } from '@kit.InputKit';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTokenOverride } from '../../theme/tokens/SparkComponentTokens';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { sparkAreaToSv, sparkColorClamp, sparkHsvaToArgb, SparkHsva, sparkPushRecent, sparkTrackRatio } from './ColorPickerLogic';
import { ColorPickerStyle } from './ColorPickerStyle';

/** colour math constants of the saturation / value overlays (white → transparent, transparent → black) */
const SV_WHITE: string = '#FFFFFFFF';
const SV_WHITE_CLEAR: string = '#00FFFFFF';
const SV_BLACK: string = '#FF000000';
const SV_BLACK_CLEAR: string = '#00000000';

/**
 * Recently committed colours, shared by every SColorPanel / SColorPicker with `recent: true` (most recent first,
 * kept for the app's lifetime). `SparkColorRecents.shared.clear()` empties it; `push(value, limit)` seeds it.
 */
@ObservedV2
export class SparkColorRecents {
  @Trace items: string[] = [];

  static get shared(): SparkColorRecents {
    return SPARK_COLOR_RECENTS;
  }

  push(value: string, limit: number): void {
    this.items = sparkPushRecent(this.items, value, limit);
  }

  clear(): void {
    this.items = [];
  }
}

// module-level (not a static initializer): created after the @ObservedV2 decorator ran, so it is observed
const SPARK_COLOR_RECENTS: SparkColorRecents = new SparkColorRecents();

/** Transparency checkerboard filling its parent (rows of a repeating hard-stop gradient, no images). */
@ComponentV2
export struct SparkCheckerboard {
  /** cell size (vp) */
  @Param cell: number = 4;
  @Param light: string = '#FFFFFFFF';
  @Param dark: string = '#FFDDDDDD';
  @Local measuredWidth: number = 0;
  @Local measuredHeight: number = 0;

  @Computed
  get rows(): number[] {
    const n = Math.max(1, Math.min(64, Math.ceil(this.measuredHeight / Math.max(1, this.cell))));
    const out: number[] = [];
    for (let i = 0; i < n; i++) {
      out.push(i);
    }
    return out;
  }

  private stops(odd: boolean): Array<[ResourceColor, number]> {
    const f = this.measuredWidth > 0 ? Math.min(0.5, this.cell / this.measuredWidth) : 0.5;
    const a = odd ? this.dark : this.light;
    const b = odd ? this.light : this.dark;
    return [[a, 0], [a, f], [b, f], [b, 2 * f]];
  }

  build() {
    Column() {
      ForEach(this.rows, (i: number) => {
        Row()
          .width('100%')
          .height(this.cell)
          .linearGradient({ direction: GradientDirection.Right, colors: this.stops(i % 2 === 1), repeating: true })
      }, (i: number) => `${i}`)
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_: Area, n: Area) => {
      this.measuredWidth = Number(n.width);
      this.measuredHeight = Number(n.height);
    })
  }
}

/** A colour chip: checkerboard + colour, rounded, bordered. Purely visual. */
@ComponentV2
export struct SparkColorChip {
  /** `#AARRGGBB` */
  @Param argb: string = '#00000000';
  @Param chipWidth: number = 20;
  @Param chipHeight: number = 20;
  @Param radius: number = 4;
  @Param style: ColorPickerStyle = new ColorPickerStyle();
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Stack() {
      if (SparkColor.fromArgbHex(this.argb).a < 0.999) {
        SparkCheckerboard({ cell: 4, light: this.style.checkerLight, dark: this.style.checkerDark })
      }
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor(this.argb)
    }
    .width(this.chipWidth)
    .height(this.chipHeight)
    .border({ width: this.theme.borderWidth, color: this.style.borderColor, radius: this.radius })
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }
}

/** Saturation (x) / value (y) area: hue base + white → transparent + transparent → black overlays. */
@ComponentV2
export struct SparkColorArea {
  @Param hue: number = 0;
  @Param sat: number = 0;
  @Param bright: number = 0;
  @Param style: ColorPickerStyle = new ColorPickerStyle();
  @Param disabled: boolean = false;
  @Param label: string = '';
  @Param valueText: string = '';
  @Event onPick: (s: number, v: number) => void = () => {
  };
  @Event onCommit: () => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local measuredWidth: number = 0;
  @Local measuredHeight: number = 0;
  @Local dragging: boolean = false;

  @Computed
  get hueColor(): string {
    return sparkHsvaToArgb(new SparkHsva(this.hue, 1, 1, 1), false);
  }

  @Computed
  get thumbColor(): string {
    return sparkHsvaToArgb(new SparkHsva(this.hue, this.sat, this.bright, 1), false);
  }

  private pickAt(x: number, y: number): void {
    const sv = sparkAreaToSv(x, y, this.measuredWidth, this.measuredHeight);
    this.onPick(sv[0], sv[1]);
  }

  private pickEvent(e: GestureEvent): void {
    if (e.fingerList.length > 0) {
      this.pickAt(e.fingerList[0].localX, e.fingerList[0].localY);
    }
  }

  private nudge(ds: number, dv: number): void {
    this.onPick(sparkColorClamp(this.sat + ds, 0, 1), sparkColorClamp(this.bright + dv, 0, 1));
    this.onCommit();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack() {
        Row().width('100%').height('100%').backgroundColor(this.hueColor)
        Row()
          .width('100%')
          .height('100%')
          .linearGradient({ direction: GradientDirection.Right, colors: [[SV_WHITE, 0], [SV_WHITE_CLEAR, 1]] })
        Row()
          .width('100%')
          .height('100%')
          .linearGradient({ direction: GradientDirection.Bottom, colors: [[SV_BLACK_CLEAR, 0], [SV_BLACK, 1]] })
      }
      .width('100%')
      .height('100%')
      .border({ width: this.theme.borderWidth, color: this.style.borderColor, radius: this.style.radius })
      .clip(true)

      Row()
        .width(this.style.thumbSize)
        .height(this.style.thumbSize)
        .backgroundColor(this.thumbColor)
        .border({ width: 2, color: this.style.thumbBorderColor, radius: this.style.thumbSize / 2 })
        .shadow(SparkTokenOverride.shadowOptions(this.style.thumbShadow))
        .position({
          x: this.sat * this.measuredWidth - this.style.thumbSize / 2,
          y: (1 - this.bright) * this.measuredHeight - this.style.thumbSize / 2
        })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height(this.style.areaHeight)
    .focusable(!this.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityRole(AccessibilityRoleType.SLIDER)
    .accessibilityText(this.label)
    .accessibilityDescription(this.valueText)
    .onAreaChange((_: Area, n: Area) => {
      this.measuredWidth = Number(n.width);
      this.measuredHeight = Number(n.height);
    })
    .onClick((e: ClickEvent) => {
      if (!this.disabled) {
        this.pickAt(e.x, e.y);
        this.onCommit();
      }
    })
    .gesture(
      PanGesture({ direction: PanDirection.All, distance: 1 })
        .onActionStart((e: GestureEvent) => {
          if (!this.disabled) {
            this.dragging = true;
            this.pickEvent(e);
          }
        })
        .onActionUpdate((e: GestureEvent) => {
          if (this.dragging) {
            this.pickEvent(e);
          }
        })
        .onActionEnd(() => {
          if (this.dragging) {
            this.dragging = false;
            this.onCommit();
          }
        })
        .onActionCancel(() => {
          if (this.dragging) {
            this.dragging = false;
            this.onCommit();
          }
        })
    )
    .onKeyEvent((e: KeyEvent) => {
      if (this.disabled || e.type !== KeyType.Down) {
        return;
      }
      if (e.keyCode === KeyCode.KEYCODE_DPAD_RIGHT) {
        this.nudge(0.01, 0);
      } else if (e.keyCode === KeyCode.KEYCODE_DPAD_LEFT) {
        this.nudge(-0.01, 0);
      } else if (e.keyCode === KeyCode.KEYCODE_DPAD_UP) {
        this.nudge(0, 0.01);
      } else if (e.keyCode === KeyCode.KEYCODE_DPAD_DOWN) {
        this.nudge(0, -0.01);
      }
    })
  }
}

/** Horizontal colour track (hue or alpha): gradient over an optional checkerboard, round thumb. */
@ComponentV2
export struct SparkColorTrack {
  /** thumb position 0..1 */
  @Param ratio: number = 0;
  /** gradient colours (`#AARRGGBB`), evenly spaced */
  @Param stops: string[] = [];
  @Param checker: boolean = false;
  /** thumb fill (`#AARRGGBB`) */
  @Param thumbColor: string = '#00000000';
  @Param style: ColorPickerStyle = new ColorPickerStyle();
  @Param disabled: boolean = false;
  @Param label: string = '';
  @Param valueText: string = '';
  /** ratio change per arrow key */
  @Param keyStep: number = 0.01;
  @Event onPick: (ratio: number) => void = () => {
  };
  @Event onCommit: () => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local trackLength: number = 0;
  @Local dragging: boolean = false;

  @Computed
  get gradient(): Array<[ResourceColor, number]> {
    const n = this.stops.length;
    return this.stops.map((c: string, i: number): [ResourceColor, number] => [c, n > 1 ? i / (n - 1) : 0]);
  }

  @Computed
  get boxHeight(): number {
    return Math.max(this.style.thumbSize, this.style.trackHeight);
  }

  private pickAt(x: number): void {
    this.onPick(sparkTrackRatio(x, this.trackLength, this.style.thumbSize));
  }

  private nudge(d: number): void {
    this.onPick(sparkColorClamp(this.ratio + d, 0, 1));
    this.onCommit();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack() {
        if (this.checker) {
          SparkCheckerboard({ cell: this.style.trackHeight / 2, light: this.style.checkerLight,
            dark: this.style.checkerDark })
        }
        Row()
          .width('100%')
          .height('100%')
          .linearGradient({ direction: GradientDirection.Right, colors: this.gradient })
      }
      .width('100%')
      .height(this.style.trackHeight)
      .position({ x: 0, y: (this.boxHeight - this.style.trackHeight) / 2 })
      .border({ width: this.theme.borderWidth, color: this.style.borderColor, radius: this.style.trackHeight / 2 })
      .clip(true)

      Row()
        .width(this.style.thumbSize)
        .height(this.style.thumbSize)
        .backgroundColor(this.thumbColor)
        .border({ width: 2, color: this.style.thumbBorderColor, radius: this.style.thumbSize / 2 })
        .shadow(SparkTokenOverride.shadowOptions(this.style.thumbShadow))
        .position({
          x: this.ratio * Math.max(0, this.trackLength - this.style.thumbSize),
          y: (this.boxHeight - this.style.thumbSize) / 2
        })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height(this.boxHeight)
    .responseRegion({ x: 0, y: -8, width: '100%', height: this.boxHeight + 16 })
    .focusable(!this.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityRole(AccessibilityRoleType.SLIDER)
    .accessibilityText(this.label)
    .accessibilityDescription(this.valueText)
    .onAreaChange((_: Area, n: Area) => {
      this.trackLength = Number(n.width);
    })
    .onClick((e: ClickEvent) => {
      if (!this.disabled) {
        this.pickAt(e.x);
        this.onCommit();
      }
    })
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 1 })
        .onActionStart((e: GestureEvent) => {
          if (!this.disabled && e.fingerList.length > 0) {
            this.dragging = true;
            this.pickAt(e.fingerList[0].localX);
          }
        })
        .onActionUpdate((e: GestureEvent) => {
          if (this.dragging && e.fingerList.length > 0) {
            this.pickAt(e.fingerList[0].localX);
          }
        })
        .onActionEnd(() => {
          if (this.dragging) {
            this.dragging = false;
            this.onCommit();
          }
        })
        .onActionCancel(() => {
          if (this.dragging) {
            this.dragging = false;
            this.onCommit();
          }
        })
    )
    .onKeyEvent((e: KeyEvent) => {
      if (this.disabled || e.type !== KeyType.Down) {
        return;
      }
      if (e.keyCode === KeyCode.KEYCODE_DPAD_RIGHT || e.keyCode === KeyCode.KEYCODE_DPAD_UP) {
        this.nudge(this.keyStep);
      } else if (e.keyCode === KeyCode.KEYCODE_DPAD_LEFT || e.keyCode === KeyCode.KEYCODE_DPAD_DOWN) {
        this.nudge(-this.keyStep);
      }
    })
  }
}

/** selected swatch: background-coloured gap + foreground ring (vp) */
const SWATCH_GAP: number = 2;
const SWATCH_RING: number = 2;

/** A preset / recent swatch button: instant hover ring, pressed fade (system pressed state), gap + ring when selected. */
@ComponentV2
export struct SparkColorSwatch {
  /** `#AARRGGBB` */
  @Param argb: string = '#00000000';
  @Param selected: boolean = false;
  @Param style: ColorPickerStyle = new ColorPickerStyle();
  @Param disabled: boolean = false;
  @Param label: string = '';
  @Event onPick: () => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local ix: SparkInteraction = new SparkInteraction();

  aboutToAppear(): void {
    this.ix.enabled = !this.disabled;
  }

  @Monitor('disabled')
  syncDisabled(): void {
    this.ix.enabled = !this.disabled;
    if (this.disabled) {
      this.ix.reset();
    }
  }

  @Styles
  normalStyle() {
    .opacity(1)
  }

  @Styles
  pressedStyle() {
    .opacity(0.7)
  }

  build() {
    Stack() {
      SparkColorChip({
        argb: this.argb,
        chipWidth: this.style.swatchSize,
        chipHeight: this.style.swatchSize,
        radius: this.style.swatchRadius,
        style: this.style
      })
      if (this.selected) {
        // a 2vp background-coloured gap between the colour and the ring (ring-offset look)
        Column()
          .width(this.style.swatchSize)
          .height(this.style.swatchSize)
          .border({ width: SWATCH_GAP, color: this.theme.colors.background, radius: this.style.swatchRadius })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width(this.style.swatchSize)
    .height(this.style.swatchSize)
    // selected: solid foreground ring around the gap; hover: a faint 1vp ring (instant, never animated)
    .outline({
      width: this.selected ? SWATCH_RING : (this.ix.hovered ? 1 : 0),
      color: this.selected ? this.theme.colors.foreground : SparkColor.alpha(this.theme.colors.foreground, 0.25),
      radius: this.style.swatchRadius + (this.selected ? SWATCH_RING : 1),
      style: OutlineStyle.SOLID
    })
    .stateStyles({ normal: this.normalStyle, pressed: this.pressedStyle })
    .focusable(!this.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(this.label)
    .accessibilitySelected(this.selected)
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .onClick(() => {
      if (!this.disabled) {
        this.onPick();
      }
    })
    .onKeyEvent((e: KeyEvent) => {
      if (!this.disabled && e.type === KeyType.Down && e.keyCode === KeyCode.KEYCODE_ENTER) {
        this.onPick();
      }
    })
  }
}
