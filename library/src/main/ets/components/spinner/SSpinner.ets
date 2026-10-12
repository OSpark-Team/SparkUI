import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

/**
 * shadcn-vue `Spinner`: a `loader-circle` icon with `animate-spin` (1s linear, infinite).
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
    .onAppear(() => {
      this.angle = 0;
      this.getUIContext().animateTo({ duration: 1000, curve: Curve.Linear, iterations: -1 }, () => {
        this.angle = 360;
      });
    })
  }
}
