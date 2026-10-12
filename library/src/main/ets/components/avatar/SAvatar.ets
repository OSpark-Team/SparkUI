import { SparkAnim } from '../../core/SparkAnim';
import { SparkTones } from '../../core/SparkTone';
import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

/** Named avatar sizes: xs 20 · sm 24 · default 32 · md 40 · lg 48 · xl 64 (vp). */
export type AvatarSize = 'xs' | 'sm' | 'default' | 'md' | 'lg' | 'xl';
export type AvatarShape = 'circle' | 'rounded' | 'square';
/** Presence dot: online (success) · away (warning) · busy (destructive) · offline (muted). */
export type AvatarStatus = 'online' | 'away' | 'busy' | 'offline';

/** Diameter in vp of a numeric or named avatar size. */
export function sparkAvatarSize(sizing: number | AvatarSize): number {
  if (typeof sizing === 'number') {
    return sizing;
  }
  switch (sizing) {
    case 'xs':
      return 20;
    case 'sm':
      return 24;
    case 'md':
      return 40;
    case 'lg':
      return 48;
    case 'xl':
      return 64;
    default:
      return 32;
  }
}

/** Corner radius of an avatar shape at diameter `d`. */
export function sparkAvatarRadius(shape: AvatarShape, d: number, themeRadius: number): number {
  if (shape === 'circle') {
    return d / 2;
  }
  if (shape === 'square') {
    return Math.min(4, d / 8);
  }
  return Math.min(themeRadius, d / 4);
}

function fallbackFontSize(t: SparkTheme, d: number): number {
  if (d <= 24) {
    return d <= 20 ? 9 : t.text.xs - 2;
  }
  if (d <= 40) {
    return t.text.sm;
  }
  if (d <= 56) {
    return t.text.base;
  }
  return t.text.xl;
}

/**
 * shadcn-vue `Avatar` (+ `AvatarImage` / `AvatarFallback`): `relative flex size-8 shrink-0 overflow-hidden
 * rounded-full`. The fallback (initials on `bg-muted`) shows while the image loads, when `src` is missing,
 * and when loading fails.
 *
 * Variants: `sizing` (vp or xs | sm | default | md | lg | xl), `shape` (circle | rounded | square), `status`
 * (presence dot: online | away | busy | offline) and `ring` (a 2vp background-coloured ring, for overlapping).
 *
 * ```
 * SAvatar({ src: 'https://github.com/unovue.png', fallback: 'CN' })
 * SAvatar({ fallback: 'JD', sizing: 48 })
 * SAvatar({ fallback: 'ER', sizing: 'lg', shape: 'rounded', status: 'online' })
 * ```
 */
@ComponentV2
export struct SAvatar {
  @Param src: ResourceStr | undefined = undefined;
  /** Initials shown when there is no image. */
  @Param fallback: string = '';
  /** Diameter in vp (`size-8` = 32) or a named size. */
  @Param sizing: number | AvatarSize = 32;
  @Param shape: AvatarShape = 'circle';
  /** Presence dot at the bottom-right. */
  @Param status: AvatarStatus | undefined = undefined;
  /** 2vp ring in the background colour (`ring-2 ring-background`). */
  @Param ring: boolean = false;
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
  get diameter(): number {
    return sparkAvatarSize(this.sizing);
  }

  @Computed
  get radius(): number {
    return sparkAvatarRadius(this.shape, this.diameter, this.theme.radiusMd);
  }

  @Computed
  get statusColor(): string {
    switch (this.status) {
      case 'online':
        return SparkTones.base(this.theme, 'success');
      case 'away':
        return SparkTones.base(this.theme, 'warning');
      case 'busy':
        return this.theme.colors.destructive;
      default:
        return this.theme.colors.mutedForeground;
    }
  }

  @Computed
  get statusSize(): number {
    return Math.max(8, Math.round(this.diameter * 0.28));
  }

  @Computed
  get accessibleName(): string {
    const name = this.label ?? this.fallback;
    return this.status !== undefined ? `${name}, ${this.status}` : name;
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Stack() {
        if (!this.loaded) {
          Text(this.fallback)
            .fontSize(fallbackFontSize(this.theme, this.diameter))
            .fontWeight(this.theme.text.weightMedium)
            .fontColor(this.theme.colors.foreground)
            .maxLines(1)
            .textAlign(TextAlign.Center)
        }
        if (this.src !== undefined && !this.failed) {
          Image(this.src)
            .width(this.diameter)
            .height(this.diameter)
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
      .width(this.diameter)
      .height(this.diameter)
      .backgroundColor(this.loaded ? Color.Transparent : this.theme.colors.muted)
      .border({ width: 0, radius: this.radius })
      .clip(true)

      if (this.status !== undefined) {
        Row()
          .width(this.statusSize)
          .height(this.statusSize)
          .backgroundColor(this.statusColor)
          .border({ width: 2, color: this.theme.colors.background, radius: this.statusSize / 2 })
          .translate({
            x: this.shape === 'circle' ? -this.diameter * 0.04 : 2,
            y: this.shape === 'circle' ? -this.diameter * 0.04 : 2
          })
      }
    }
    .width(this.diameter)
    .height(this.diameter)
    .flexShrink(0)
    .outline({
      width: this.ring ? 2 : 0,
      color: this.theme.colors.background,
      radius: this.radius + 2,
      style: OutlineStyle.SOLID
    })
    .accessibilityGroup(true)
    .accessibilityText(this.accessibleName)
  }
}

/**
 * Overlapping avatar stack (shadcn's `flex -space-x-2 *:ring-2 *:ring-background` pattern) with a "+N" bubble.
 * Data-driven, because a slot's children cannot be restyled: pass the initials and (optionally) the images.
 *
 * ```
 * SAvatarGroup({ fallbacks: ['CN', 'LR', 'ER', 'JD', 'MK'], max: 3 })                 // CN LR ER +2
 * SAvatarGroup({ fallbacks: ['A', 'B'], sources: [url1, url2], sizing: 'lg', extra: 12 })   // A B +12
 * ```
 */
@ComponentV2
export struct SAvatarGroup {
  /** Initials of each avatar (one avatar per entry). */
  @Param fallbacks: string[] = [];
  /** Image of each avatar, by index (optional, may be shorter). */
  @Param sources: ResourceStr[] = [];
  /** Avatars shown before the "+N" bubble; 0 = all. */
  @Param max: number = 0;
  /** Additional count not in the lists (e.g. total from a server), added to the "+N" bubble. */
  @Param extra: number = 0;
  @Param sizing: number | AvatarSize = 32;
  @Param shape: AvatarShape = 'circle';
  /** Overlap in vp; defaults to a quarter of the diameter (`-space-x-2` at 32vp). */
  @Param overlap: number | undefined = undefined;
  /** Accessible name of the group. */
  @Param label: string | undefined = undefined;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Computed
  get diameter(): number {
    return sparkAvatarSize(this.sizing);
  }

  @Computed
  get shown(): number[] {
    const n = this.max > 0 ? Math.min(this.max, this.fallbacks.length) : this.fallbacks.length;
    const out: number[] = [];
    for (let i = 0; i < n; i++) {
      out.push(i);
    }
    return out;
  }

  @Computed
  get hiddenCount(): number {
    return this.fallbacks.length - this.shown.length + Math.max(0, this.extra);
  }

  @Computed
  get gap(): number {
    return this.overlap ?? Math.round(this.diameter / 4);
  }

  build() {
    Row() {
      ForEach(this.shown, (i: number) => {
        SAvatar({
          src: i < this.sources.length ? this.sources[i] : undefined,
          fallback: this.fallbacks[i],
          sizing: this.diameter,
          shape: this.shape,
          ring: true
        })
          .margin({ left: i === 0 ? 0 : -this.gap })
      }, (i: number) => `${i}:${this.fallbacks[i]}`)
      if (this.hiddenCount > 0) {
        Text(`+${this.hiddenCount}`)
          .width(this.diameter)
          .height(this.diameter)
          .textAlign(TextAlign.Center)
          .fontSize(fallbackFontSize(this.theme, this.diameter))
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.theme.colors.mutedForeground)
          .backgroundColor(this.theme.colors.muted)
          .border({ width: 0, radius: sparkAvatarRadius(this.shape, this.diameter, this.theme.radiusMd) })
          .outline({
            width: 2,
            color: this.theme.colors.background,
            radius: sparkAvatarRadius(this.shape, this.diameter, this.theme.radiusMd) + 2,
            style: OutlineStyle.SOLID
          })
          .margin({ left: this.shown.length === 0 ? 0 : -this.gap })
          .accessibilityText(`${this.hiddenCount} more`)
      }
    }
    .padding(2)
    .accessibilityGroup(true)
    .accessibilityText(this.label ?? '')
  }
}
