import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkAnim } from '../../core/SparkAnim';
import { SparkNoopModifier } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

/** Loading motion: Tailwind `animate-pulse`, a moving highlight, or static. */
export type SkeletonMotion = 'pulse' | 'shimmer' | 'none';
/** Ready-made layouts: text lines, avatar + two lines, media card. */
export type SkeletonPreset = 'text' | 'list' | 'card';

/** Applies the optional box size (only the dimensions that were given). */
class SkeletonSizeModifier implements AttributeModifier<ColumnAttribute> {
  boxWidth: Length | undefined;
  boxHeight: Length | undefined;

  constructor(boxWidth: Length | undefined, boxHeight: Length | undefined) {
    this.boxWidth = boxWidth;
    this.boxHeight = boxHeight;
  }

  applyNormalAttribute(instance: ColumnAttribute): void {
    if (this.boxWidth !== undefined) {
      instance.width(this.boxWidth);
    }
    if (this.boxHeight !== undefined) {
      instance.height(this.boxHeight);
    }
  }
}

/** Width of text line `i` of `lines`: full lines, the last one 60% (a paragraph's ragged end). */
export function sparkSkeletonLineWidth(i: number, lines: number): string {
  return lines > 1 && i === lines - 1 ? '60%' : '100%';
}

/**
 * shadcn-vue `Skeleton`: `bg-accent animate-pulse rounded-md`.
 * Size it with `boxWidth` / `boxHeight` (named so they do not clash with the universal width/height
 * attributes), or with `modifier`. `circle` makes it fully rounded (avatars).
 *
 * Variants: `motion` pulse (default) | shimmer (a highlight sweeping across) | none; `lines` renders a paragraph
 * of N text lines (the last one shorter); `preset` text | list (avatar + two lines) | card (media + lines).
 *
 * ```
 * SSkeleton({ boxWidth: 48, boxHeight: 48, circle: true })
 * SSkeleton({ boxWidth: '100%', boxHeight: 16 })
 * SSkeleton({ lines: 3, motion: 'shimmer' })
 * SSkeleton({ preset: 'list' })
 * SSkeleton({ preset: 'card', boxWidth: 280 })
 * ```
 * The motion runs on its own child node (removed when `motion` changes) and follows `--motion-skeleton-*`.
 */
@ComponentV2
export struct SSkeleton {
  @Param boxWidth: Length | undefined = undefined;
  @Param boxHeight: Length | undefined = undefined;
  @Param circle: boolean = false;
  @Param motion: SkeletonMotion = 'pulse';
  /** Paragraph of N text lines (overrides the plain box). */
  @Param lines: number = 0;
  @Param preset: SkeletonPreset | undefined = undefined;
  @Param modifier: AttributeModifier<ColumnAttribute> = new SparkNoopModifier<ColumnAttribute>();
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Computed
  get sizeModifier(): SkeletonSizeModifier {
    return new SkeletonSizeModifier(this.boxWidth, this.boxHeight);
  }

  @Computed
  get lineIndices(): number[] {
    const n = this.preset === 'text' && this.lines <= 0 ? 3 : Math.max(0, Math.floor(this.lines));
    const out: number[] = [];
    for (let i = 0; i < n; i++) {
      out.push(i);
    }
    return out;
  }

  build() {
    if (this.preset === 'list') {
      Column() {
        Row({ space: 16 }) {
          SSkeletonBlock({ blockWidth: 48, blockHeight: 48, radius: 24, motion: this.motion })
          Column({ space: 8 }) {
            SSkeletonBlock({ blockWidth: '90%', blockHeight: 16, radius: this.theme.radiusMd, motion: this.motion })
            SSkeletonBlock({ blockWidth: '60%', blockHeight: 16, radius: this.theme.radiusMd, motion: this.motion })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .accessibilityLevel('no')
      .attributeModifier(this.sizeModifier)
      .attributeModifier(this.modifier)
    } else if (this.preset === 'card') {
      Column({ space: 12 }) {
        SSkeletonBlock({ blockWidth: '100%', blockHeight: 125, radius: this.theme.radiusXl, motion: this.motion })
        SSkeletonBlock({ blockWidth: '80%', blockHeight: 16, radius: this.theme.radiusMd, motion: this.motion })
        SSkeletonBlock({ blockWidth: '60%', blockHeight: 16, radius: this.theme.radiusMd, motion: this.motion })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .accessibilityLevel('no')
      .attributeModifier(this.sizeModifier)
      .attributeModifier(this.modifier)
    } else if (this.lineIndices.length > 0) {
      Column({ space: 8 }) {
        ForEach(this.lineIndices, (i: number) => {
          SSkeletonBlock({
            blockWidth: sparkSkeletonLineWidth(i, this.lineIndices.length),
            blockHeight: 16,
            radius: this.theme.radiusMd,
            motion: this.motion
          })
        }, (i: number) => `${i}`)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .accessibilityLevel('no')
      .attributeModifier(this.sizeModifier)
      .attributeModifier(this.modifier)
    } else {
      Column() {
        SSkeletonFill({ motion: this.motion })
        this.content()
      }
      .attributeModifier(this.sizeModifier)
      // a radius larger than half the box is clamped by ArkUI, which yields a circle / pill
      .border({ width: 0, radius: this.circle ? 9999 : this.theme.radiusMd })
      .clip(true)
      .accessibilityLevel('no')
      .attributeModifier(this.modifier)
    }
  }
}

/** One placeholder box of a preset / paragraph. */
@ComponentV2
struct SSkeletonBlock {
  @Param blockWidth: Length = '100%';
  @Param blockHeight: Length = 16;
  @Param radius: number = 6;
  @Param motion: SkeletonMotion = 'pulse';

  build() {
    Column() {
      SSkeletonFill({ motion: this.motion })
    }
    .width(this.blockWidth)
    .height(this.blockHeight)
    .border({ width: 0, radius: this.radius })
    .clip(true)
  }
}

/**
 * The `bg-accent` fill behind a skeleton's content (positioned, so it never affects layout). Each motion is a
 * separate node, so switching or disabling the motion removes the infinite animation with it.
 */
@ComponentV2
struct SSkeletonFill {
  @Param motion: SkeletonMotion = 'pulse';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Stack() {
      if (this.motion === 'pulse') {
        SSkeletonPulse({ color: this.theme.colors.accent })
      } else {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.theme.colors.accent)
        if (this.motion === 'shimmer') {
          SSkeletonShimmer({ highlight: SparkColor.mix(this.theme.colors.accent, this.theme.colors.background, 0.6) })
        }
      }
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .clip(true)
  }
}

/** Tailwind `animate-pulse`: opacity 1 → 0.5 → 1, forever. */
@ComponentV2
struct SSkeletonPulse {
  @Param color: string = '#FF000000';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local level: number = 1;

  build() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor(this.color)
      .opacity(this.level)
      .onAppear(() => {
        SparkAnim.loop(this.getUIContext(), this.theme, 'skeleton', 'normal', 5, () => {
          this.level = 1;
        }, () => {
          this.level = 0.5;
        }, true, 'cubic-bezier(0.4, 0, 0.6, 1)');
      })
  }
}

/** A soft highlight band sweeping left → right, forever. */
@ComponentV2
struct SSkeletonShimmer {
  @Param highlight: string = '#FFFFFFFF';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local boxWidth: number = 0;
  @Local x: number = 0;

  private start(): void {
    const w = this.boxWidth;
    if (w <= 0) {
      return;
    }
    const moving = SparkAnim.loop(this.getUIContext(), this.theme, 'skeleton', 'normal', 8, () => {
      this.x = -w;
    }, () => {
      this.x = w;
    }, false, 'ease-in-out');
    if (!moving) {
      this.x = -w;
    }
  }

  build() {
    Row()
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 90,
        colors: [[SparkColor.alpha(this.highlight, 0), 0], [this.highlight, 0.5], [SparkColor.alpha(this.highlight, 0), 1]]
      })
      .translate({ x: this.x })
      .onAreaChange((_: Area, n: Area) => {
        const w = Number(n.width);
        if (Math.abs(w - this.boxWidth) > 0.5) {
          this.boxWidth = w;
          this.start();
        }
      })
  }
}
