import { ColorMetrics, LengthMetrics } from '@kit.ArkUI';
import { SparkColor } from '../theme/color/SparkColor';
import { SparkTheme } from '../theme/tokens/SparkTheme';

/** Modifier that does nothing; default for every component's `modifier` param. */
export class SparkNoopModifier<T> implements AttributeModifier<T> {
}

/** "#AARRGGBB" token → ColorMetrics (for APIs such as focusBox). */
export function sparkColorMetrics(hex: string): ColorMetrics {
  const c = SparkColor.fromArgbHex(hex);
  return ColorMetrics.rgba(Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255), c.a);
}

/**
 * shadcn focus-visible ring (`ring-ring/50 ring-[3px]`) drawn with the system focus box, which ArkUI
 * shows only for keyboard focus — exactly CSS :focus-visible semantics.
 */
export function sparkFocusRing(theme: SparkTheme): FocusBoxStyle {
  return {
    strokeColor: sparkColorMetrics(SparkColor.alpha(theme.colors.ring, 0.5)),
    strokeWidth: LengthMetrics.vp(3),
    margin: LengthMetrics.vp(0)
  };
}

/**
 * Swallows taps on a disabled control. Developers attach clicks to SparkUI components with the native
 * `.onClick()` universal event, which lives on the custom-component node and still fires when the inner
 * control is `enabled(false)` (verified on device). A child tap gesture wins over the ancestor's click,
 * so installing a no-op tap while disabled blocks it.
 */
export class SparkTapBlocker implements GestureModifier {
  blocked: boolean;

  constructor(blocked: boolean) {
    this.blocked = blocked;
  }

  applyGesture(event: UIGestureEvent): void {
    event.clearGestures();
    if (this.blocked) {
      event.addGesture(new TapGestureHandler().onAction(() => {
      }));
    }
  }
}
