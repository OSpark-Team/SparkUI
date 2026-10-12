import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkNoopModifier } from '../../core/SparkModifier';

/**
 * shadcn-vue `AspectRatio`: a full-width box whose height follows `ratio` (width / height). Children are
 * centred; give them `width('100%').height('100%')` to fill (e.g. an Image with `objectFit(ImageFit.Cover)`).
 *
 * ```
 * SAspectRatio({ ratio: 16 / 9 }) {
 *   Image(this.photoUrl).width('100%').height('100%').objectFit(ImageFit.Cover)
 * }
 * ```
 */
@ComponentV2
export struct SAspectRatio {
  /** width / height, e.g. 16 / 9. */
  @Param ratio: number = 1;
  @Param modifier: AttributeModifier<StackAttribute> = new SparkNoopModifier<StackAttribute>();
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    Stack() {
      this.content()
    }
    .width('100%')
    .aspectRatio(this.ratio > 0 ? this.ratio : 1)
    .attributeModifier(this.modifier)
  }
}
