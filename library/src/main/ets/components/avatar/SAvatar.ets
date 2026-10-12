import { SparkAnim } from '../../core/SparkAnim';
import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

/**
 * shadcn-vue `Avatar` (+ `AvatarImage` / `AvatarFallback`): `relative flex size-8 shrink-0 overflow-hidden
 * rounded-full`. The fallback (initials on `bg-muted`) shows while the image loads, when `src` is missing,
 * and when loading fails.
 *
 * ```
 * SAvatar({ src: 'https://github.com/unovue.png', fallback: 'CN' })
 * SAvatar({ fallback: 'JD', sizing: 48 })
 * ```
 */
@ComponentV2
export struct SAvatar {
  @Param src: ResourceStr | undefined = undefined;
  /** Initials shown when there is no image. */
  @Param fallback: string = '';
  /** Diameter in vp (`size-8` = 32). */
  @Param sizing: number = 32;
  /** Accessible name; defaults to `fallback`. */
  @Param label: string | undefined = undefined;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local failed: boolean = false;
  @Local loaded: boolean = false;

  @Monitor('src')
  resetLoad(): void {
    this.failed = false;
    this.loaded = false;
  }

  @Computed
  get fallbackFontSize(): number {
    if (this.sizing <= 24) {
      return this.theme.text.xs;
    }
    if (this.sizing <= 40) {
      return this.theme.text.sm;
    }
    if (this.sizing <= 56) {
      return this.theme.text.base;
    }
    return this.theme.text.xl;
  }

  build() {
    Stack() {
      if (!this.loaded) {
        Text(this.fallback)
          .fontSize(this.fallbackFontSize)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.theme.colors.foreground)
          .maxLines(1)
          .textAlign(TextAlign.Center)
      }
      if (this.src !== undefined && !this.failed) {
        Image(this.src)
          .width(this.sizing)
          .height(this.sizing)
          .objectFit(ImageFit.Cover)
          .draggable(false)
          .opacity(this.loaded ? 1 : 0)
          .animation(SparkAnim.attr(this.theme, 'avatar', 'normal'))
          .onComplete(() => {
            this.loaded = true;
          })
          .onError(() => {
            this.failed = true;
            this.loaded = false;
          })
      }
    }
    .width(this.sizing)
    .height(this.sizing)
    .flexShrink(0)
    .backgroundColor(this.loaded ? Color.Transparent : this.theme.colors.muted)
    .border({ width: 0, radius: this.sizing / 2 })
    .clip(true)
    .accessibilityText(this.label ?? this.fallback)
  }
}
