import { sparkEmptyBuilder } from '../core/Builders';
import { SparkContext } from '../core/SparkContext';
import { SparkUI } from '../core/SparkUI';
import { SparkLayoutContext } from './SparkLayoutContext';

/** SparkContext key of container layout contexts. */
export const SPARK_LAYOUT_KEY: string = 'spark.layout';

/**
 * Nearest SparkContainer context of a component (render-tree lookup), or undefined when it is not inside
 * one. Call from `onDidBuild()` and keep the result in a `@Local`; fall back to the
 * `@Consumer('sparkLayout')` value:
 *
 * ```
 * @Consumer('sparkLayout') windowLayout: SparkLayoutContext = SparkUI.layout.root;
 * @Local container: SparkLayoutContext | undefined = undefined;
 * onDidBuild() { this.container ??= resolveSparkLayout(this.getUIContext(), this.getUniqueId()); }
 * get layout(): SparkLayoutContext { return this.container ?? this.windowLayout; }
 * ```
 */
export function resolveSparkLayout(uiContext: UIContext, componentId: number): SparkLayoutContext | undefined {
  return SparkContext.resolve<SparkLayoutContext>(uiContext, componentId, SPARK_LAYOUT_KEY);
}

/**
 * Container query boundary: measures itself and provides a local `sparkLayout` context whose
 * `widthClass` / `heightClass` follow this container instead of the window. Window-level signals
 * (posture, modality, safe area …) are shared.
 */
@ComponentV2
export struct SparkContainer {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Provider('sparkLayout') layout: SparkLayoutContext = new SparkLayoutContext(SparkUI.layout.env, true);

  aboutToAppear(): void {
    // Start from the window classes so the first frame is close to final.
    this.layout.widthClass = SparkUI.layout.root.widthClass;
    this.layout.heightClass = SparkUI.layout.root.heightClass;
    // Slot content resolves @Consumer against the page that defines it, not against this container
    // (verified on device), so the container context is also published along the render tree.
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), SPARK_LAYOUT_KEY, this.layout);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.content()
    }
    .width('100%')
    // onAreaChange also fires for the first layout (onSizeChange does not — verified on device)
    .onAreaChange((_: Area, n: Area) => {
      this.layout.updateSize(Number(n.width), Number(n.height), SparkUI.layout.thresholds);
    })
  }
}
