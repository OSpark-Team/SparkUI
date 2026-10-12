import { SparkAnim } from '../../core/SparkAnim';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

/**
 * shadcn-vue `Spinner`: a `loader-circle` icon with `animate-spin` (linear, infinite). Motion key `spinner`: one turn
 * takes 5 × the normal duration (1 s by default); with motion off the icon is shown still. Remove the spinner to
 * stop it (it restarts when it is shown again).
 *
 * ```
 * SSpinner()
 * SSpinner({ sizing: 24, color: theme.colors.mutedForeground })
 * ```
 */
@ComponentV2
export struct SSpinner {
  /** Icon size in vp (`size-4` = 16). */
  @Param sizing: number = 16;
  /** Defaults to the `foreground` token (currentColor). */
  @Param color: ResourceColor | undefined = undefined;
  /** Accessible name. */
  @Param label: string = 'Loading';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local angle: number = 0;

  build() {
    Stack() {
      SIcon({ name: 'loader-circle', sizing: this.sizing, color: this.color ?? this.theme.colors.foreground })
    }
    .width(this.sizing)
    .height(this.sizing)
    .rotate({ angle: this.angle })
    .accessibilityText(this.label)
    .onAppear(() => sparkSpin(this.getUIContext(), this.theme, (a: number) => {
      this.angle = a;
    }))
  }
}

/**
 * Start the infinite `spinner` rotation of a node that exists only while spinning (call from its `onAppear`):
 * the angle is reset to 0 synchronously first, so a node shown again after being removed spins again.
 */
export function sparkSpin(ctx: UIContext, theme: SparkTheme, setAngle: (a: number) => void): void {
  SparkAnim.loop(ctx, theme, 'spinner', 'normal', 5, () => setAngle(0), () => setAngle(360), false, 'linear');
}
