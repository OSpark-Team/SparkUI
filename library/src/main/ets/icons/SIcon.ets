import { SparkUI } from '../core/SparkUI';
import { SparkTheme } from '../theme/tokens/SparkTheme';
import { scalePathCommands, SparkIconData } from './SparkIconData';
import { SparkIcons } from './SparkIcons';

/**
 * Unified icon. Renders a lucide vector icon by name, or a HarmonyOS Symbol when one is mapped via
 * `SparkIcons.useSymbol()` or passed directly through `symbol`.
 *
 * ```
 * SIcon({ name: 'chevron-down', sizing: 16 })
 * SIcon({ symbol: $r('sys.symbol.house') })
 * ```
 */
@ComponentV2
export struct SIcon {
  @Param name: string = '';
  /** HarmonyOS Symbol resource; takes precedence over `name`. */
  @Param symbol: Resource | undefined = undefined;
  /** vp */
  @Param sizing: number = 16;
  /** Defaults to the `foreground` token. */
  @Param color: ResourceColor | undefined = undefined;
  /** Stroke width in the 24-unit icon box (lucide default 2); scales with `sizing`. */
  @Param strokeWidth: number = 2;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Computed
  get data(): SparkIconData | undefined {
    return SparkIcons.get(this.name);
  }

  /**
   * Path data scaled from the 24-unit box to px at the current size. Path commands are in px, so this depends on
   * the window density as well: reading `env.pxPerVp` recomputes the paths when it changes (a tablet window
   * switching into free-window mode is rescaled — cached px paths then no longer fit the vp box and the icon
   * shows clipped / offset).
   */
  @Computed
  get scaledPaths(): string[] {
    const d = this.data;
    if (d === undefined) {
      return [];
    }
    const density = SparkUI.layout.env.pxPerVp;
    const k = (density > 0 ? this.getUIContext().vp2px(this.sizing) : this.sizing) / 24;
    return d.paths.map((p: string) => scalePathCommands(p, k));
  }

  @Computed
  get paint(): ResourceColor {
    return this.color ?? this.theme.colors.foreground;
  }

  @Computed
  get resolvedSymbol(): Resource | undefined {
    return this.symbol ?? SparkIcons.symbolFor(this.name);
  }

  build() {
    if (this.resolvedSymbol !== undefined) {
      SymbolGlyph(this.resolvedSymbol)
        .fontSize(this.sizing)
        .fontColor([this.paint])
        .accessibilityLevel('no')
    } else if (this.data !== undefined) {
      Shape() {
        ForEach(this.scaledPaths, (p: string) => {
          // Paint attributes go on each Path: Shape-level values are not re-propagated on update
          // (verified on device: icons kept their old colour after a theme switch).
          Path()
            .commands(p)
            .fill(this.data?.filled ? this.paint : Color.Transparent)
            .stroke(this.data?.filled ? Color.Transparent : this.paint)
            .strokeWidth(this.strokeWidth * this.sizing / 24)
            .strokeLineCap(LineCapStyle.Round)
            .strokeLineJoin(LineJoinStyle.Round)
            .antiAlias(true)
        }, (p: string, idx: number) => `${idx}:${p}`)
      }
      .width(this.sizing)
      .height(this.sizing)
      .accessibilityLevel('no')
    } else {
      Blank()
        .width(this.sizing)
        .height(this.sizing)
    }
  }
}
