import { SparkLayoutMonitor } from '../layout/SparkLayoutMonitor';
import { SparkSizeClassName } from '../layout/SparkLayoutContext';
import { SparkThemeController } from '../theme/SparkThemeController';
import { SparkTheme } from '../theme/tokens/SparkTheme';

/**
 * SparkUI runtime facade: the global theme store and layout monitor.
 * Usually you only wrap pages in `SparkProvider`; use these for imperative control
 * (`SparkUI.themes.setMode('dark')`, `SparkUI.themes.loadRawfile('theme.css')` …).
 */
export class SparkUI {
  static readonly themes: SparkThemeController = new SparkThemeController();
  static readonly layout: SparkLayoutMonitor = new SparkLayoutMonitor();
  private static wired: boolean = false;
  private static ui: UIContext | undefined = undefined;

  /** UI context of the most recently attached SparkProvider (used by imperative APIs such as toast()). */
  static get uiContext(): UIContext | undefined {
    return SparkUI.ui;
  }

  /** The global live token store (default value of every `@Consumer('sparkTheme')`). */
  static get theme(): SparkTheme {
    return SparkUI.themes.theme;
  }

  static attach(uiContext: UIContext): void {
    if (!SparkUI.wired) {
      SparkUI.wired = true;
      SparkUI.layout.onSizeClassChange((c: SparkSizeClassName) => SparkUI.themes.setSizeClass(c));
    }
    SparkUI.ui = uiContext;
    SparkUI.layout.attach(uiContext);
    SparkUI.themes.attach(uiContext);
    SparkUI.themes.setSizeClass(SparkUI.layout.root.widthClass);
  }

  static detach(): void {
    SparkUI.themes.detach();
    SparkUI.layout.detach();
  }
}
