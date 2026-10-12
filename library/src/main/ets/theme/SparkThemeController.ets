import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { CustomTheme } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { resourceManager } from '@kit.LocalizationKit';
import { ThemeCssParser } from './css/ThemeCssParser';
import { ThemeResolver } from './css/ThemeResolver';
import { ThemeDiagnostic, ThemeSource } from './css/ThemeSource';
import { accentCss, presetCss, SparkAccentName, SparkPresetName } from './presets/Presets';
import { SystemThemeBridge } from './SystemThemeBridge';
import { SparkTheme, SparkThemeMode } from './tokens/SparkTheme';
import { SparkAnim, SparkMotionOptions } from '../core/SparkAnim';

/** Outcome of loading a theme file. Loading never throws. */
export class ThemeLoadResult {
  /** false when at least one `error` diagnostic was produced (valid parts are still applied) */
  ok: boolean = true;
  diagnostics: ThemeDiagnostic[] = [];

  static of(diags: ThemeDiagnostic[]): ThemeLoadResult {
    const r = new ThemeLoadResult();
    r.diagnostics = diags;
    r.ok = !diags.some((d: ThemeDiagnostic) => d.severity === 'error');
    return r;
  }
}

export interface ThemeLoadOptions {
  /** Preset the file is layered on (missing / invalid tokens fall back to it). Default: current preset. */
  base?: SparkPresetName;
  /** Theme display name. */
  name?: string;
}

/**
 * Runtime theme store controller (singleton: `SparkUI.themes`).
 * Owns the live {@link SparkTheme}, the colour mode, theme loading and the system theme bridge.
 */
@ObservedV2
export class SparkThemeController {
  /** The live token store every SparkUI component reads (directly or via @Consumer). */
  readonly theme: SparkTheme = new SparkTheme();
  @Trace mode: SparkThemeMode = 'system';
  @Trace systemDark: boolean = false;
  @Trace preset: SparkPresetName = 'neutral';
  /** Accent colour layered on the base preset. */
  @Trace accent: SparkAccentName = 'none';
  /** Size class used for `@size()` blocks; driven by SparkLayout. */
  @Trace sizeClass: string = 'compact';
  /** Diagnostics of the last load/refresh (parse + apply). */
  @Trace diagnostics: ThemeDiagnostic[] = [];
  /** Animate colour changes on theme / mode switch. */
  @Trace transitions: boolean = true;
  /** Mirror tokens into the system theme (ThemeControl / WithTheme) for native components. */
  @Trace systemBridge: boolean = true;
  /** Also force the app colour mode (status bar, system dialogs) when mode is light/dark. */
  syncAppColorMode: boolean = true;
  /** Theme passed to WithTheme by SparkProvider; replaced on every refresh. */
  @Trace bridgeTheme: CustomTheme = {};

  /** effective = base preset ⊕ accent ⊕ overrides */
  private source: ThemeSource = new ThemeSource();
  /** user theme file / editor variables, layered last */
  private overrides: ThemeSource = new ThemeSource();
  private sourceDiagnostics: ThemeDiagnostic[] = [];
  private customName: string | undefined = undefined;
  private presetSources: Map<string, ThemeSource> = new Map<string, ThemeSource>();
  private uiContext: UIContext | undefined = undefined;
  private appContext: common.ApplicationContext | undefined = undefined;
  private envCallbackId: number = -1;
  private attachCount: number = 0;

  constructor() {
    this.source = this.presetSource('neutral');
    this.refresh(false);
  }

  get isDark(): boolean {
    return this.mode === 'dark' || (this.mode === 'system' && this.systemDark);
  }

  // ---------------------------------------------------------------------------------------------
  // Lifecycle (called by SparkProvider)
  // ---------------------------------------------------------------------------------------------

  /** Bind to a UI context: tracks system colour mode. Ref-counted; safe to call from many providers. */
  attach(uiContext: UIContext): void {
    this.attachCount++;
    this.uiContext = uiContext;
    if (this.appContext !== undefined) {
      return;
    }
    try {
      const host = uiContext.getHostContext();
      if (host === undefined) {
        return;
      }
      this.systemDark = SparkThemeController.readSystemDark(host);
      this.appContext = host.getApplicationContext();
      this.envCallbackId = this.appContext.on('environment', {
        onConfigurationUpdated: (config) => {
          // While the app colour mode is forced, config.colorMode reflects our own override.
          if (this.mode === 'system' || !this.syncAppColorMode) {
            const dark = config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
            if (dark !== this.systemDark) {
              this.systemDark = dark;
              this.refresh(this.transitions);
            }
          }
        },
        onMemoryLevel: () => {
        }
      });
      this.refresh(false);
      this.applyAppColorMode();
    } catch (e) {
      // Running outside an ability (previewer / unit test): stay on defaults.
    }
  }

  detach(): void {
    this.attachCount = Math.max(0, this.attachCount - 1);
    if (this.attachCount > 0 || this.appContext === undefined) {
      return;
    }
    try {
      this.appContext.off('environment', this.envCallbackId);
    } catch (e) {
    }
    this.appContext = undefined;
    this.envCallbackId = -1;
  }

  // ---------------------------------------------------------------------------------------------
  // Mode & presets
  // ---------------------------------------------------------------------------------------------

  setMode(mode: SparkThemeMode): void {
    if (mode === this.mode) {
      return;
    }
    // Selection state is applied synchronously first, so only the token colours take part in the transition.
    SparkAnim.commit(() => {
      this.mode = mode;
      if (mode === 'system' && this.uiContext !== undefined) {
        const host = this.uiContext.getHostContext();
        if (host !== undefined) {
          this.systemDark = SparkThemeController.readSystemDark(host);
        }
      }
    });
    this.applyAppColorMode();
    this.refresh(this.transitions);
  }

  toggleDark(): void {
    this.setMode(this.isDark ? 'light' : 'dark');
  }

  /** Switch the gray base (keeps accent and overrides such as radius). */
  usePreset(name: SparkPresetName): void {
    SparkAnim.commit(() => {
      this.preset = name;
    });
    this.rebuildSource();
    this.refresh(this.transitions);
  }

  /** Switch the accent colour theme ('none' = monochrome shadcn default). */
  useAccent(name: SparkAccentName): void {
    SparkAnim.commit(() => {
      this.accent = name;
    });
    this.rebuildSource();
    this.refresh(this.transitions);
  }

  /** Drop loaded / edited overrides, back to preset + accent. */
  resetOverrides(): void {
    this.overrides = new ThemeSource();
    this.sourceDiagnostics = [];
    this.customName = undefined;
    this.rebuildSource();
    this.refresh(this.transitions);
  }

  setSizeClass(size: string): void {
    if (size === this.sizeClass) {
      return;
    }
    this.sizeClass = size;
    if (this.source.sizes.size > 0) {
      this.refresh(false);
    }
  }

  // ---------------------------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------------------------

  /** Load a theme from CSS-subset or JSON text (auto-detected). */
  loadString(text: string, options?: ThemeLoadOptions): ThemeLoadResult {
    const parsed = text.trim().startsWith('{') ? ThemeCssParser.parseJson(text) : ThemeCssParser.parse(text);
    this.preset = options?.base ?? this.preset;
    this.customName = options?.name ?? 'custom';
    this.overrides = parsed;
    this.rebuildSource();
    this.sourceDiagnostics = parsed.diagnostics;
    this.refresh(this.transitions);
    return ThemeLoadResult.of(this.diagnostics);
  }

  /** Load from `resources/rawfile/<path>` of the given context (defaults to the attached UI context). */
  loadRawfile(path: string, options?: ThemeLoadOptions, context?: Context): ThemeLoadResult {
    try {
      const ctx = context ?? this.uiContext?.getHostContext();
      if (ctx === undefined) {
        return this.failure(`no context available to read rawfile "${path}"`);
      }
      const bytes = ctx.resourceManager.getRawFileContentSync(path);
      return this.loadString(SparkThemeController.decode(bytes), options);
    } catch (e) {
      return this.failure(`cannot read rawfile "${path}": ${(e as Error).message}`);
    }
  }

  /** Load from an absolute sandbox file path. */
  loadFile(path: string, options?: ThemeLoadOptions): ThemeLoadResult {
    try {
      return this.loadString(fileIo.readTextSync(path), options);
    } catch (e) {
      return this.failure(`cannot read file "${path}": ${(e as Error).message}`);
    }
  }

  /** Download and load a theme. The host app needs `ohos.permission.INTERNET`. */
  async loadUrl(url: string, options?: ThemeLoadOptions): Promise<ThemeLoadResult> {
    const req = http.createHttp();
    try {
      const resp = await req.request(url, { method: http.RequestMethod.GET, expectDataType: http.HttpDataType.STRING });
      if (resp.responseCode < 200 || resp.responseCode >= 300) {
        return this.failure(`HTTP ${resp.responseCode} for ${url}`);
      }
      return this.loadString(resp.result as string, options);
    } catch (e) {
      return this.failure(`cannot download "${url}": ${(e as Error).message}`);
    } finally {
      req.destroy();
    }
  }

  /** Current effective theme source (preset + overrides), e.g. for export. */
  exportCss(): string {
    return this.source.toCss();
  }

  exportJson(): string {
    return this.source.toJson();
  }

  /**
   * Configure a component's animation, like a CSS transition (stored as `--motion-<component>-*` variables,
   * so it is exported with the theme):
   * ```
   * SparkUI.themes.setMotion('accordion', { duration: 320, ease: 'spring(0.45, 0.85)' })
   * SparkUI.themes.setMotion('tooltip', { enabled: false })
   * ```
   */
  setMotion(component: string, options: SparkMotionOptions): ThemeLoadResult {
    let css = ':root {';
    if (options.duration !== undefined) {
      css += ` --motion-${component}-duration: ${options.duration}ms;`;
    }
    if (options.ease !== undefined) {
      css += ` --motion-${component}-ease: ${options.ease};`;
    }
    if (options.enabled !== undefined) {
      css += ` --motion-${component}-enabled: ${options.enabled};`;
    }
    css += ' }';
    return this.applyOverrideCss(css);
  }

  /** Master animation switch (`--motion-enabled`). */
  setMotionEnabled(enabled: boolean): ThemeLoadResult {
    return this.applyOverrideCss(`:root { --motion-enabled: ${enabled}; }`);
  }

  private applyOverrideCss(css: string): ThemeLoadResult {
    const parsed = ThemeCssParser.parse(css);
    this.overrides = this.overrides.merge(parsed);
    this.rebuildSource();
    this.refresh(false);
    return ThemeLoadResult.of(this.diagnostics);
  }

  /** Set (or override) a single variable at runtime, e.g. from the theme editor. */
  setVariable(name: string, value: string, block: 'root' | 'dark' = 'root'): ThemeLoadResult {
    const varName = name.startsWith('--') ? name : '--' + name;
    const css = block === 'dark' ? `.dark { ${varName}: ${value}; }` : `:root { ${varName}: ${value}; }`;
    const parsed = ThemeCssParser.parse(css);
    this.overrides = this.overrides.merge(parsed);
    this.rebuildSource();
    this.refresh(false);
    return ThemeLoadResult.of(this.diagnostics);
  }

  // ---------------------------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------------------------

  /** Re-resolve tokens and push them into the live store. */
  refresh(animate: boolean): void {
    const dark = this.isDark;
    const scratch = new SparkTheme();
    // 1) defaults: the base preset for this appearance (guarantees every token has a valid value)
    ThemeResolver.apply(this.presetSource(this.preset), dark, this.sizeClass, scratch);
    // 2) effective source
    const applyDiags = ThemeResolver.apply(this.source, dark, this.sizeClass, scratch);
    scratch.name = this.customName ?? (this.accent === 'none' ? this.preset : `${this.preset}/${this.accent}`);
    this.diagnostics = this.sourceDiagnostics.concat(applyDiags);

    const commit = (): void => {
      this.theme.copyFrom(scratch);
    };
    if (animate && this.uiContext !== undefined) {
      SparkAnim.run(this.uiContext, scratch, 'theme', 'slow', commit);
    } else {
      SparkAnim.commit(commit);
    }
    if (this.systemBridge) {
      this.bridgeTheme = SystemThemeBridge.toCustomTheme(this.theme.colors);
      SystemThemeBridge.applyDefault(this.theme.colors);
    }
  }

  private failure(message: string): ThemeLoadResult {
    const d = new ThemeDiagnostic('error', 0, '', message);
    this.diagnostics = [d];
    return ThemeLoadResult.of([d]);
  }

  private rebuildSource(): void {
    let src = this.presetSource(this.preset);
    if (this.accent !== 'none') {
      src = src.merge(this.accentSource(this.accent));
    }
    this.source = src.merge(this.overrides);
  }

  private accentSource(name: string): ThemeSource {
    const key = 'accent:' + name;
    let s = this.presetSources.get(key);
    if (s === undefined) {
      s = ThemeCssParser.parse(accentCss(name));
      this.presetSources.set(key, s);
    }
    return s;
  }

  private presetSource(name: string): ThemeSource {
    let s = this.presetSources.get(name);
    if (s === undefined) {
      s = ThemeCssParser.parse(presetCss(name) ?? presetCss('neutral') as string);
      this.presetSources.set(name, s);
    }
    return s;
  }

  private applyAppColorMode(): void {
    if (!this.syncAppColorMode || this.appContext === undefined) {
      return;
    }
    try {
      const m = this.mode === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK :
        (this.mode === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT :
        ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      this.appContext.setColorMode(m);
    } catch (e) {
    }
  }

  private static readSystemDark(ctx: Context): boolean {
    try {
      return ctx.resourceManager.getConfigurationSync().colorMode === resourceManager.ColorMode.DARK;
    } catch (e) {
      return false;
    }
  }

  private static decode(bytes: Uint8Array): string {
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    return decoder.decodeToString(bytes);
  }
}
