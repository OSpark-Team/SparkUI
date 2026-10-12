import { SparkAnim, SparkSpeed } from '../../core/SparkAnim';
import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  SparkTransitionEffectFactory, sparkTransitionEffect, sparkTransitionTiming, SparkTransitionTiming
} from './SparkTransitionEffect';
import { sparkEmptyKeyBuilder } from './SSwitchTransition';
import { SparkTransitionName } from './TransitionSpec';

/** Main axis of an STransitionGroup. */
export type SparkTransitionGroupAxis = 'vertical' | 'horizontal';

/**
 * Vue `<TransitionGroup>`: a keyed list whose inserted / removed items animate with the preset (or custom
 * effects), while the remaining items glide to their new positions (Vue's FLIP `move` class). The move is an
 * ArkUI layout animation: the rendered list is updated inside `SparkAnim.runWith` (animateTo + applySync), so
 * position changes caused by the update animate with the same duration / curve.
 *
 * ```
 * STransitionGroup({ items: this.ids, itemBuilder: this.renderItem, name: 'slide-left', gap: 8 })
 * @LocalBuilder renderItem(key: string) { SItem({ title: this.titleOf(key) }) }
 * ```
 * Update `items` by assigning a new array (`this.ids = [...]`); keys must be unique and stable.
 */
@ComponentV2
export struct STransitionGroup {
  @Param items: string[] = [];
  @BuilderParam itemBuilder: (key: string) => void = sparkEmptyKeyBuilder;
  @Param name: SparkTransitionName = 'fade';
  @Param axis: SparkTransitionGroupAxis = 'vertical';
  @Param gap: number = 0;
  /** Slide distance of the 'slide-*' presets (default 100 % of the item). */
  @Param distance: string = '100%';
  @Param motionKey: string = 'transition-group';
  @Param speed: SparkSpeed = 'normal';
  @Param duration: number = -1;
  @Param ease: string = '';
  @Param enterEffect: SparkTransitionEffectFactory | undefined = undefined;
  @Param leaveEffect: SparkTransitionEffectFactory | undefined = undefined;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local rendered: string[] = [];
  @Local armed: boolean = false;

  aboutToAppear(): void {
    this.rendered = this.items.slice();
  }

  private timing(): SparkTransitionTiming {
    return sparkTransitionTiming(this.theme, this.motionKey, this.speed, this.duration, this.ease);
  }

  private effect(): TransitionEffect {
    if (!this.armed) {
      return TransitionEffect.IDENTITY;
    }
    return sparkTransitionEffect(this.name, true, this.distance, this.timing(), this.enterEffect, this.leaveEffect);
  }

  @Monitor('items')
  syncItems(): void {
    const next = this.items.slice();
    if (!this.armed) {
      this.rendered = next;
      return;
    }
    const t = this.timing();
    SparkAnim.runWith(this.getUIContext(), t.duration, t.curve, () => {
      this.rendered = next;
    });
  }

  @Builder
  entries() {
    ForEach(this.rendered, (key: string) => {
      Stack({ alignContent: Alignment.TopStart }) {
        this.itemBuilder(key)
      }
      .transition(this.effect())
    }, (key: string) => key)
  }

  build() {
    if (this.axis === 'horizontal') {
      Row({ space: this.gap }) {
        this.entries()
      }
      .alignItems(VerticalAlign.Top)
      .onAppear(() => {
        this.armed = true;
      })
    } else {
      Column({ space: this.gap }) {
        this.entries()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .onAppear(() => {
        this.armed = true;
      })
    }
  }
}
