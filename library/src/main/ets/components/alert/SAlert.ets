import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkAnim } from '../../core/SparkAnim';
import { SparkContext } from '../../core/SparkContext';
import { SparkNoopModifier } from '../../core/SparkModifier';
import { SparkTone, SparkTones } from '../../core/SparkTone';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkColor } from '../../theme/color/SparkColor';
import { sparkVariantProp, SparkTokenOverride } from '../../theme/tokens/SparkComponentTokens';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SparkTokenReader } from '../../theme/tokens/SparkTokenReader';
import { SButton } from '../button/SButton';

const KEY: string = 'spark.alert';

export type AlertVariant = 'default' | 'destructive' | 'success' | 'warning' | 'info';

/**
 * Per-instance token overrides of an alert (ADR D13): `SAlert({ tokens: { borderWidth: 0, radius: 0 } })`.
 * Instance → theme `--alert-<variant>-<prop>` / `--alert-<prop>` → recipe.
 */
export interface AlertTokens {
  background?: string;
  /** title / icon colour */
  foreground?: string;
  descriptionColor?: string;
  borderColor?: string;
  borderWidth?: number;
  radius?: number;
  paddingX?: number;
  paddingY?: number;
}

/** Title / icon colour of an alert variant (`text-destructive`, status tones; card foreground by default). */
export function sparkAlertForeground(t: SparkTheme, variant: AlertVariant): string {
  const fallback = variant === 'default' ? t.colors.cardForeground : SparkTones.base(t, variant as SparkTone);
  return t.comp.color('alert', sparkVariantProp(variant, 'foreground'), fallback);
}

/** Description colour (`text-muted-foreground`, destructive: `text-destructive/90`). */
export function sparkAlertDescriptionColor(t: SparkTheme, variant: AlertVariant): string {
  const fallback = variant === 'destructive' ? SparkColor.alpha(t.colors.destructive, 0.9) : t.colors.mutedForeground;
  return t.comp.color('alert', sparkVariantProp(variant, 'description-color'), fallback);
}

/** Alert variant shared with SAlertTitle / SAlertDescription. */
@ObservedV2
export class SparkAlertState {
  @Trace variant: AlertVariant = 'default';
  /** instance overrides (`tokens.foreground` / `tokens.descriptionColor`) */
  @Trace titleColor: string | undefined = undefined;
  @Trace descriptionColor: string | undefined = undefined;
}

function resolveAlert(uiContext: UIContext, id: number): SparkAlertState | undefined {
  return SparkContext.resolve<SparkAlertState>(uiContext, id, KEY);
}

/**
 * shadcn-vue `Alert`: `relative w-full rounded-lg border px-4 py-3 text-sm grid grid-cols-[16px_1fr] gap-x-3
 * gap-y-0.5 items-start`, `bg-card`. The `destructive` variant tints title / icon with `text-destructive` and the
 * description with `text-destructive/90`.
 *
 * `heading` / `description` are shortcuts for a title / description without a slot.
 *
 * Variants: default | destructive | success | warning | info (title and icon take the tone colour). Extras:
 * `soft` (tinted background and border), `compact` (tighter padding, centred row), `actionLabel` + `onAction`
 * (trailing outline button), `dismissible` (trailing ×; the alert hides itself and emits `onDismiss`).
 *
 * ```
 * SAlert({ icon: 'circle-check' }) {
 *   SAlertTitle({ text: 'Success! Your changes have been saved' })
 *   SAlertDescription({ text: 'This is an alert with icon, title and description.' })
 * }
 * SAlert({ variant: 'destructive', icon: 'circle-alert', heading: 'Error', description: 'Session expired.' })
 * SAlert({ variant: 'success', soft: true, icon: 'circle-check', heading: 'Deployed', dismissible: true })
 * SAlert({ variant: 'warning', compact: true, icon: 'triangle-alert', heading: 'Trial ends in 3 days',
 *   actionLabel: 'Upgrade', onAction: () => ... })
 * ```
 */
@ComponentV2
export struct SAlert {
  @Param variant: AlertVariant = 'default';
  /** lucide icon name shown in the leading column. */
  @Param icon: string | undefined = undefined;
  @Param heading: ResourceStr | undefined = undefined;
  @Param description: ResourceStr | undefined = undefined;
  /** Tinted background and border in the variant colour. */
  @Param soft: boolean = false;
  /** Tighter padding (`px-3 py-2`), items centred. */
  @Param compact: boolean = false;
  /** Text of a trailing action button. */
  @Param actionLabel: ResourceStr | undefined = undefined;
  @Event onAction: () => void = () => {
  };
  /** Trailing × button; the alert hides itself (motion key 'alert') and emits `onDismiss`. */
  @Param dismissible: boolean = false;
  @Event onDismiss: () => void = () => {
  };
  @Param modifier: AttributeModifier<RowAttribute> = new SparkNoopModifier<RowAttribute>();
  /** Per-instance token overrides (instance → theme `--alert-*` → recipe), see {@link AlertTokens}. */
  @Param tokens: AlertTokens = {};
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local state: SparkAlertState = new SparkAlertState();
  @Local dismissed: boolean = false;

  aboutToAppear(): void {
    this.state.variant = this.variant;
    this.syncTokens();
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('variant')
  syncVariant(): void {
    this.state.variant = this.variant;
  }

  @Monitor('tokens')
  syncTokens(): void {
    const t = this.tokens;
    this.state.titleColor = t.foreground === undefined ? undefined : SparkTokenOverride.color(t.foreground, '#00000000');
    this.state.descriptionColor = t.descriptionColor === undefined ? undefined :
      SparkTokenOverride.color(t.descriptionColor, '#00000000');
  }

  private get tok(): SparkTokenReader {
    return new SparkTokenReader(this.theme, 'alert');
  }

  private vp(p: string): string {
    return sparkVariantProp(this.variant, p);
  }

  @Computed
  get fg(): string {
    return SparkTokenOverride.color(this.tokens.foreground, sparkAlertForeground(this.theme, this.variant));
  }

  @Computed
  get edgeWidth(): number {
    return this.tok.len('border-width', this.tokens.borderWidth, this.theme.borderWidth);
  }

  @Computed
  get radius(): number {
    return this.tok.len('radius', this.tokens.radius, this.theme.radiusLg);
  }

  @Computed
  get paddingX(): number {
    return this.tok.len('padding-x', this.tokens.paddingX, this.compact ? 12 : 16);
  }

  @Computed
  get paddingY(): number {
    return this.tok.len('padding-y', this.tokens.paddingY, this.compact ? 8 : 12);
  }

  @Computed
  get tinted(): boolean {
    return this.soft && this.variant !== 'default';
  }

  @Computed
  get surface(): string {
    const recipe = this.tinted ? SparkTones.resolve(this.theme, this.variant as SparkTone).soft : this.theme.colors.card;
    return this.tok.color(this.vp('background'), this.tokens.background, recipe);
  }

  @Computed
  get edgeColor(): string {
    const recipe = this.tinted ? SparkTones.resolve(this.theme, this.variant as SparkTone).border :
      this.theme.colors.border;
    return this.tok.color(this.vp('border-color'), this.tokens.borderColor, recipe);
  }

  private dismiss(): void {
    SparkAnim.run(this.getUIContext(), this.theme, 'alert', 'fast', () => {
      this.dismissed = true;
    });
    this.onDismiss();
  }

  build() {
    Column() {
      if (!this.dismissed) {
        Row({ space: this.compact ? 8 : 12 }) {
          if (this.icon !== undefined) {
            // [&>svg]:size-4 [&>svg]:translate-y-0.5 text-current
            SIcon({ name: this.icon, sizing: 16, color: this.fg })
              .margin({ top: this.compact ? 0 : 2 })
          }
          Column({ space: 2 }) {
            if (this.heading !== undefined) {
              SAlertTitle({ text: this.heading })
            }
            if (this.description !== undefined) {
              SAlertDescription({ text: this.description })
            }
            this.content()
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          if (this.actionLabel !== undefined) {
            SButton({ text: this.actionLabel, variant: 'outline', sizing: 'sm' })
              .margin({ top: this.compact ? -4 : -2, bottom: -4 })
              .onClick(() => this.onAction())
          }
          if (this.dismissible) {
            SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'x', label: 'Dismiss' })
              .margin({ top: -6, bottom: -6, right: -6 })
              .onClick(() => this.dismiss())
          }
        }
        .width('100%')
        .alignItems(this.compact ? VerticalAlign.Center : VerticalAlign.Top)
        .padding({ left: this.paddingX, right: this.paddingX, top: this.paddingY, bottom: this.paddingY })
        .backgroundColor(this.surface)
        .border({ width: this.edgeWidth, color: this.edgeColor, radius: this.radius })
        .accessibilityGroup(true)
        .transition(SparkAnim.enter(this.theme, 'alert', 'fast', 0.98))
        .attributeModifier(this.modifier)
      }
    }
    .width('100%')
  }
}

/** `col-start-2 line-clamp-1 min-h-4 font-medium tracking-tight`. */
@ComponentV2
export struct SAlertTitle {
  @Param text: ResourceStr = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local alert: SparkAlertState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.alert === undefined) {
      this.alert = resolveAlert(this.getUIContext(), this.getUniqueId());
    }
  }

  build() {
    Text(this.text)
      .fontSize(this.theme.text.sm)
      .lineHeight(this.theme.text.leadingSm)
      .fontWeight(this.theme.text.weightMedium)
      .letterSpacing(-0.025 * this.theme.text.sm)
      .fontColor(this.alert?.titleColor ?? sparkAlertForeground(this.theme, this.alert?.variant ?? 'default'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .constraintSize({ minHeight: 16 })
  }
}

/** `text-muted-foreground col-start-2 text-sm [&_p]:leading-relaxed` (destructive: `text-destructive/90`). */
@ComponentV2
export struct SAlertDescription {
  @Param text: ResourceStr | undefined = undefined;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local alert: SparkAlertState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.alert === undefined) {
      this.alert = resolveAlert(this.getUIContext(), this.getUniqueId());
    }
  }

  @Computed
  get fg(): string {
    return this.alert?.descriptionColor ?? sparkAlertDescriptionColor(this.theme, this.alert?.variant ?? 'default');
  }

  build() {
    Column({ space: 4 }) {
      if (this.text !== undefined) {
        Text(this.text)
          .fontSize(this.theme.text.sm)
          // leading-relaxed (1.625)
          .lineHeight(this.theme.text.sm * 1.625)
          .fontColor(this.fg)
      }
      this.content()
    }
    .alignItems(HorizontalAlign.Start)
  }
}
