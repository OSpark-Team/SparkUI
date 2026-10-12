import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkNoopModifier } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

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

/**
 * shadcn-vue `Skeleton`: `bg-accent animate-pulse rounded-md`.
 * Size it with `boxWidth` / `boxHeight` (named so they do not clash with the universal width/height
 * attributes), or with `modifier`. `circle` makes it fully rounded (avatars).
 *
 * ```
 * SSkeleton({ boxWidth: 48, boxHeight: 48, circle: true })
 * SSkeleton({ boxWidth: '100%', boxHeight: 16 })
 * ```
 */
@ComponentV2
export struct SSkeleton {
  @Param boxWidth: Length | undefined = undefined;
  @Param boxHeight: Length | undefined = undefined;
  @Param circle: boolean = false;
  @Param modifier: AttributeModifier<ColumnAttribute> = new SparkNoopModifier<ColumnAttribute>();
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local pulse: number = 1;

  @Computed
  get sizeModifier(): SkeletonSizeModifier {
    return new SkeletonSizeModifier(this.boxWidth, this.boxHeight);
  }

  build() {
    Column() {
      this.content()
    }
    .attributeModifier(this.sizeModifier)
    .backgroundColor(this.theme.colors.accent)
    // a radius larger than half the box is clamped by ArkUI, which yields a circle / pill
    .border({ width: 0, radius: this.circle ? 9999 : this.theme.radiusMd })
    .clip(true)
    .opacity(this.pulse)
    .accessibilityLevel('no')
    .attributeModifier(this.modifier)
    .onAppear(() => {
      // Tailwind animate-pulse: opacity 1 → 0.5 → 1 every 2s, cubic-bezier(0.4, 0, 0.6, 1)
      this.pulse = 1;
      this.getUIContext().animateTo({
        duration: 1000,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate
      }, () => {
        this.pulse = 0.5;
      });
    })
  }
}
