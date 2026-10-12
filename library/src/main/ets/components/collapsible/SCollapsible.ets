import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkCollapse } from '../../primitives/SparkCollapse';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';

const KEY: string = 'spark.collapsible';

/** Disclosure state plus the collapsible's disabled flag. */
@ObservedV2
export class SparkCollapsibleState extends SparkDisclosure {
  @Trace disabled: boolean = false;
}

/**
 * shadcn-vue `Collapsible`: an interactive component which expands / collapses a panel.
 *
 * ```
 * SCollapsible({ defaultOpen: false }) {
 *   SCollapsibleTrigger() { SButton({ variant: 'ghost', sizing: 'icon', icon: 'chevrons-up-down', label: 'Toggle' }) }
 *   SCollapsibleContent() { Text('Hidden content') }
 * }
 * // controlled: SCollapsible({ open: this.open!! }) { ... }
 * ```
 */
@ComponentV2
export struct SCollapsible {
  /** Controlled open state (use with `!!`). Leave undefined for uncontrolled. */
  @Param open: boolean | undefined = undefined;
  @Event $open: (open: boolean) => void = () => {
  };
  @Param defaultOpen: boolean = false;
  @Event onOpenChange: (open: boolean) => void = () => {
  };
  /** Ignore trigger taps. */
  @Param disabled: boolean = false;
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local state: SparkCollapsibleState = new SparkCollapsibleState();

  aboutToAppear(): void {
    this.state.controlled = this.open !== undefined;
    this.state.open = this.open ?? this.defaultOpen;
    this.state.disabled = this.disabled;
    this.state.emit = (v: boolean) => {
      this.$open(v);
      this.onOpenChange(v);
    };
    SparkContext.provide(this.getUIContext(), this.getUniqueId(), KEY, this.state);
  }

  aboutToDisappear(): void {
    SparkContext.revoke(this.getUniqueId());
  }

  @Monitor('open')
  syncOpen(): void {
    if (this.open !== undefined) {
      this.state.assign(this.open);
    }
  }

  @Monitor('disabled')
  syncDisabled(): void {
    this.state.disabled = this.disabled;
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** Toggles the collapsible when its content is tapped. */
@ComponentV2
export struct SCollapsibleTrigger {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local ctx: SparkCollapsibleState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = SparkContext.resolve<SparkCollapsibleState>(this.getUIContext(), this.getUniqueId(), KEY);
      if (this.ctx !== undefined) {
        this.ctx.triggerKey = sparkTriggerKey(this.getUniqueId());
      }
    }
  }

  build() {
    Stack() {
      this.content()
    }
    .id(sparkTriggerKey(this.getUniqueId()))
    .accessibilityDescription(this.ctx?.open === true ? 'expanded' : 'collapsed')
    .onClick(() => {
      if (this.ctx !== undefined && !this.ctx.disabled) {
        this.ctx.toggle();
      }
    })
  }
}

/** The panel; expands / collapses with a height animation. */
@ComponentV2
export struct SCollapsibleContent {
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Local ctx: SparkCollapsibleState | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = SparkContext.resolve<SparkCollapsibleState>(this.getUIContext(), this.getUniqueId(), KEY);
    }
  }

  build() {
    SparkCollapse({ open: this.ctx !== undefined && this.ctx.open }) {
      Column({ space: 8 }) {
        this.content()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }
}
