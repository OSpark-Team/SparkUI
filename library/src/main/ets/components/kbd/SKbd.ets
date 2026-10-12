import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

export type KbdSize = 'sm' | 'default' | 'lg';
/** `default`: shadcn's flat `bg-muted` key; `outline`: a raised keycap (border + bottom edge). */
export type KbdVariant = 'default' | 'outline';

/** lucide icon for well-known key names in `SKbdGroup({ keys })` ('cmd' → command …); undefined = text. */
export function sparkKbdIcon(key: string): string | undefined {
  switch (key.toLowerCase()) {
    case 'cmd':
    case 'command':
    case 'meta':
      return 'command';
    case 'enter':
    case 'return':
      return 'corner-down-left';
    case 'up':
      return 'arrow-up';
    case 'down':
      return 'arrow-down';
    case 'left':
      return 'arrow-left';
    case 'right':
      return 'arrow-right';
    default:
      return undefined;
  }
}

/**
 * shadcn-vue `Kbd`: `bg-muted text-muted-foreground h-5 min-w-5 rounded-sm px-1 font-sans text-xs font-medium`.
 *
 * Variants: `sizing` sm (16) | default (20) | lg (24) and `variant` default | outline (keycap look).
 *
 * ```
 * SKbd({ text: 'Ctrl' })
 * SKbd({ icon: 'command' })
 * SKbd({ text: 'Esc', variant: 'outline', sizing: 'lg' })
 * ```
 */
@ComponentV2
export struct SKbd {
  @Param text: ResourceStr | undefined = undefined;
  /** lucide icon name, e.g. `command`, `corner-down-left`. */
  @Param icon: string | undefined = undefined;
  @Param sizing: KbdSize = 'default';
  @Param variant: KbdVariant = 'default';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Computed
  get boxHeight(): number {
    return this.sizing === 'sm' ? 16 : (this.sizing === 'lg' ? 24 : 20);
  }

  @Computed
  get fontSize(): number {
    return this.sizing === 'sm' ? 10 : (this.sizing === 'lg' ? this.theme.text.sm : this.theme.text.xs);
  }

  @Computed
  get foreground(): string {
    return this.variant === 'outline' ? this.theme.colors.foreground : this.theme.colors.mutedForeground;
  }

  build() {
    Row({ space: 4 }) {
      if (this.icon !== undefined) {
        SIcon({ name: this.icon, sizing: this.fontSize, color: this.foreground })
      }
      if (this.text !== undefined) {
        Text(this.text)
          .fontSize(this.fontSize)
          .fontWeight(this.theme.text.weightMedium)
          .fontColor(this.foreground)
          .fontFamily('monospace')
          .maxLines(1)
      }
      this.content()
    }
    .height(this.boxHeight)
    .constraintSize({ minWidth: this.boxHeight })
    .padding({ left: this.sizing === 'lg' ? 6 : 4, right: this.sizing === 'lg' ? 6 : 4 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .flexShrink(0)
    .backgroundColor(this.variant === 'outline' ? this.theme.colors.background : this.theme.colors.muted)
    .border(this.variant === 'outline' ?
      {
        width: { left: 1, right: 1, top: 1, bottom: 2 },
        color: this.theme.colors.border,
        radius: this.theme.radiusSm
      } :
      { width: 0, radius: this.theme.radiusSm })
  }
}

/**
 * shadcn-vue `KbdGroup`: `inline-flex items-center gap-1`.
 *
 * `keys` renders a shortcut from strings, joined by `separator` (none by default); well-known names
 * (cmd / command / meta, enter / return, up / down / left / right) become icons.
 *
 * ```
 * SKbdGroup() { SKbd({ text: 'Ctrl' }); Text('+'); SKbd({ text: 'B' }) }
 * SKbdGroup({ keys: ['Ctrl', 'Shift', 'P'], separator: '+' })
 * SKbdGroup({ keys: ['cmd', 'K'], variant: 'outline' })
 * ```
 */
@ComponentV2
export struct SKbdGroup {
  @Param keys: string[] = [];
  /** Text between keys, e.g. '+' or 'then'. */
  @Param separator: string = '';
  @Param sizing: KbdSize = 'default';
  @Param variant: KbdVariant = 'default';
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Row({ space: 4 }) {
      ForEach(this.keys, (k: string, i: number) => {
        if (i > 0 && this.separator.length > 0) {
          Text(this.separator)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
        }
        if (sparkKbdIcon(k) !== undefined) {
          SKbd({ icon: sparkKbdIcon(k), sizing: this.sizing, variant: this.variant })
        } else {
          SKbd({ text: k, sizing: this.sizing, variant: this.variant })
        }
      }, (k: string, i: number) => `${i}:${k}`)
      this.content()
    }
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(this.keys.length > 0)
    .accessibilityText(this.keys.join(' '))
  }
}
