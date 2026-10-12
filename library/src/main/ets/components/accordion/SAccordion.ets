import { sparkText } from '../../core/SparkText';
import { SparkAnim } from '../../core/SparkAnim';
import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { sparkFocusRing } from '../../core/SparkModifier';
import { SparkInteraction } from '../../core/SparkInteraction';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkCollapse } from '../../primitives/SparkCollapse';
import { SparkRowPressModifier } from '../../primitives/SparkPressModifier';
import { SparkSelection } from '../../primitives/SparkSelection';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';

const KEY: string = 'spark.accordion';
const ITEM_KEY: string = 'spark.accordion.item';

export type AccordionType = 'single' | 'multiple';

/** Per-item state shared by an item's trigger and content. */
@ObservedV2
export class SparkAccordionItemState {
  @Trace value: string = '';
  @Trace disabled: boolean = false;
  @Trace root: SparkSelection | undefined = undefined;

  get open(): boolean {
    return this.root !== undefined && this.root.has(this.value);
  }

  toggle(): void {
    if (!this.disabled && this.root !== undefined) {
      this.root.toggle(this.value);
    }
  }
}

/**
 * shadcn-vue `Accordion`: a vertically stacked set of interactive headings that each reveal a section of content.
 *
 * ```
 * SAccordion({ type: 'single', collapsible: true, defaultValue: ['item-1'] }) {
 *   SAccordionItem({ value: 'item-1' }) {
 *     SAccordionTrigger({ text: 'Is it accessible?' })
 *     SAccordionContent() { Text('Yes. It adheres to the WAI-ARIA design pattern.') }
 *   }
 * }
 * // controlled: SAccordion({ type: 'multiple', value: this.open!! }) { ... }
 * ```
 *
 * `value` is always a string array (also for `type: 'single'`, where it holds at most one entry).
 */
@ComponentV2
export struct SAccordion {
  @Param type: AccordionType = 'single';
  /** `single` only: allow closing the open item by tapping it again. */
  @Param collapsible: boolean = false;
  /** Controlled open items (use with `!!`). Leave undefined for uncontrolled. */
  @Param value: string[] | undefined = undefined;
  @Event $value: (value: string[]) => void = () => {
  };
  @Param defaultValue: string[] = [];
  @Event onValueChange: (value: string[]) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkSelection = new SparkSelection();

  aboutToAppear(): void {
    this.syncOptions();
    this.state.controlled = this.value !== undefined;
    this.state.values = (this.value ?? this.defaultValue).slice();
    this.state.emit = (values: string[]) => {
      this.$value(values);
      this.onValueChange(values);
    };
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('type', 'collapsible')
  syncOptions(): void {
    this.state.multiple = this.type === 'multiple';
    this.state.collapsible = this.type === 'multiple' || this.collapsible;
  }

  @Monitor('value')
  syncValue(): void {
    if (this.value !== undefined) {
      this.state.assign(this.value);
    }
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** One section: `border-b last:border-b-0`. */
@ComponentV2
export struct SAccordionItem {
  @Param value: string = '';
  @Param disabled: boolean = false;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local item: SparkAccordionItemState = new SparkAccordionItemState();

  aboutToAppear(): void {
    this.syncItem();
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), ITEM_KEY, this.item);
  }

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.item.root === undefined) {
      const root = SparkContext.resolve<SparkSelection>(this.getUIContext(), this.getUniqueId(), KEY);
      if (root !== undefined) {
        root.register(this.getUniqueId());
        this.item.root = root;
      }
    }
  }

  aboutToDisappear(): void {
    this.item.root?.unregister(this.getUniqueId());
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('value', 'disabled')
  syncItem(): void {
    this.item.value = this.value;
    this.item.disabled = this.disabled;
  }

  @Computed
  get last(): boolean {
    return this.item.root !== undefined && this.item.root.isLast(this.getUniqueId());
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .border({ width: { bottom: this.last ? 0 : 1 }, color: this.theme.colors.border })
  }
}

/**
 * The heading row: `flex flex-1 items-start justify-between gap-4 rounded-md py-4 text-sm font-medium
 * hover:underline`, with a chevron that turns 180° while open. Tapping toggles the item.
 */
@ComponentV2
export struct SAccordionTrigger {
  @Param text: ResourceStr | undefined = undefined;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local item: SparkAccordionItemState | undefined = undefined;
  @Local ix: SparkInteraction = new SparkInteraction();

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.item === undefined) {
      this.item = SparkContext.resolve<SparkAccordionItemState>(this.getUIContext(), this.getUniqueId(), ITEM_KEY);
    }
  }

  @Computed
  get open(): boolean {
    return this.item !== undefined && this.item.open;
  }

  @Computed
  get disabled(): boolean {
    return this.item !== undefined && this.item.disabled;
  }

  @Computed
  get press(): SparkRowPressModifier {
    return new SparkRowPressModifier('#00000000', SparkColor.alpha(this.theme.colors.accent, 0.5), 1, this.disabled);
  }

  build() {
    Row({ space: 16 }) {
      Row() {
        if (this.text !== undefined) {
          Text(this.text)
            .fontSize(this.theme.text.sm)
            .fontWeight(this.theme.text.weightMedium)
            .lineHeight(this.theme.text.leadingSm)
            .fontColor(this.theme.colors.foreground)
            .decoration({
              type: this.ix.hovered ? TextDecorationType.Underline : TextDecorationType.None,
              color: this.theme.colors.foreground
            })
        }
        this.content()
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Top)

      SIcon({ name: 'chevron-down', sizing: 16, color: this.theme.colors.mutedForeground })
        .margin({ top: 2 })
        .rotate({ angle: this.open ? 180 : 0 })
        .animation(SparkAnim.attr(this.theme, 'accordion', 'normal'))
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    // horizontal inset so the pressed / hover background does not touch the text and chevron
    .padding({ top: 16, bottom: 16, left: 12, right: 12 })
    .attributeModifier(this.press)
    .border({ width: 0, radius: this.theme.radiusMd })
    .focusable(!this.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityDescription(this.open ? sparkText(this.getUIContext(), $r('app.string.spark_state_expanded'), 'expanded') : sparkText(this.getUIContext(), $r('app.string.spark_state_collapsed'), 'collapsed'))
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .onClick(() => this.item?.toggle())
  }
}

/** Collapsible body (`pt-0 pb-4 text-sm`), height-animated. */
@ComponentV2
export struct SAccordionContent {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local item: SparkAccordionItemState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.item === undefined) {
      this.item = SparkContext.resolve<SparkAccordionItemState>(this.getUIContext(), this.getUniqueId(), ITEM_KEY);
    }
  }

  @Computed
  get open(): boolean {
    return this.item !== undefined && this.item.open;
  }

  build() {
    SparkCollapse({ open: this.open, motionKey: 'accordion' }) {
      Column({ space: 8 }) {
        this.content()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ bottom: 16, left: 12, right: 12 })
    }
  }
}
