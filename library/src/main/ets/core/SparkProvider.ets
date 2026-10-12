import { SparkLayoutContext } from '../layout/SparkLayoutContext';
import { SparkTheme } from '../theme/tokens/SparkTheme';
import { sparkEmptyBuilder } from './Builders';
import { SparkUI } from './SparkUI';

/**
 * Root of a SparkUI page. Provides the theme (`sparkTheme`) and layout (`sparkLayout`) contexts,
 * bridges tokens to the system theme for native components, and paints the `background` token.
 *
 * ```
 * SparkProvider() {
 *   Column() { Button({ text: 'Hello' }) }
 * }
 * ```
 */
@ComponentV2
export struct SparkProvider {
  /** Paint the `background` token behind the content. */
  @Param paintBackground: boolean = true;
  /**
   * Immersive (edge-to-edge) layout: switches the window to full-screen layout
   * (`window.setWindowLayoutFullScreen`) so the page lays out under the status / navigation bars.
   * Content keeps its own insets — read them from `SparkUI.layout.env.safeArea` / the `sparkLayout` context.
   * (`expandSafeArea` only extends direct children of an extended container and stops at custom-component
   * boundaries — verified on device — so it cannot make a whole page immersive.)
   */
  @Param immersive: boolean = false;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Provider('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Provider('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;

  aboutToAppear(): void {
    SparkUI.attach(this.getUIContext());
    if (this.immersive) {
      SparkUI.layout.setImmersive(true);
    }
  }

  aboutToDisappear(): void {
    SparkUI.detach();
  }

  build() {
    WithTheme({
      theme: SparkUI.themes.bridgeTheme,
      colorMode: this.theme.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT
    }) {
      Stack({ alignContent: Alignment.TopStart }) {
        // Background layer extends under the status / navigation bars.
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.paintBackground ? this.theme.colors.background : Color.Transparent)
          .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM,
            SafeAreaEdge.START, SafeAreaEdge.END])
        this.content()
      }
      .width('100%')
      .height('100%')
      .onSizeChange((_: SizeOptions, n: SizeOptions) => {
        SparkUI.layout.reportRootSize(Number(n.width), Number(n.height));
      })
    }
  }
}
