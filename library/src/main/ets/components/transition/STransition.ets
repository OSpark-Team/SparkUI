import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkSpeed } from '../../core/SparkAnim';
import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  SparkTransitionEffectFactory, sparkTransitionEffect, sparkTransitionSideAnimates, sparkTransitionTiming,
  SparkTransitionTiming
} from './SparkTransitionEffect';
import { SparkTransitionName } from './TransitionSpec';

/**
 * Vue `<Transition>` for one conditional element (`v-if`): the content is inserted / removed when `show` changes
 * and animates with an official component transition (`.transition(TransitionEffect.asymmetric(...), onFinish)`).
 *
 * ```
 * STransition({ show: this.open, name: 'slide-down', onAfterLeave: () => { ... } }) {
 *   SAlert({ title: 'Saved' })
 * }
 * // custom effects (inherit the resolved duration / curve unless they set .animation()):
 * STransition({ show: this.open,
 *   enterEffect: (env: SparkTransitionEnv) => TransitionEffect.rotate({ z: 1, angle: 90 }).combine(TransitionEffect.OPACITY),
 *   leaveEffect: (env: SparkTransitionEnv) => TransitionEffect.OPACITY }) { ... }
 * ```
 * Timing: motion key `motionKey` (default 'transition', `--motion-transition-duration|ease|enabled`) at `speed`,
 * overridable per instance with `duration` (ms) / `ease`; `--motion-enabled: false` makes it instant.
 * Keyed content (switch between pages / views) → `SSwitchTransition`; lists → `STransitionGroup`.
 */
@ComponentV2
export struct STransition {
  /** Mount (true) or remove (false) the content. */
  @Param show: boolean = false;
  @Param name: SparkTransitionName = 'fade';
  /** Animate the initial render as well (Vue `appear`). */
  @Param appear: boolean = false;
  /** Slide distance of the 'slide-*' presets (length string; default 100 % of the content). */
  @Param distance: string = '100%';
  @Param motionKey: string = 'transition';
  @Param speed: SparkSpeed = 'normal';
  /** Per-instance duration in ms (-1 = from the motion key). */
  @Param duration: number = -1;
  /** Per-instance easing ('ease-out', 'cubic-bezier(...)', 'spring(0.4, 0.8)'); '' = from the motion key. */
  @Param ease: string = '';
  @Param enterEffect: SparkTransitionEffectFactory | undefined = undefined;
  @Param leaveEffect: SparkTransitionEffectFactory | undefined = undefined;
  @Event onBeforeEnter: () => void = () => {
  };
  @Event onAfterEnter: () => void = () => {
  };
  @Event onBeforeLeave: () => void = () => {
  };
  @Event onAfterLeave: () => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local mounted: boolean = false;
  /** Effects are IDENTITY until the host has appeared (so a non-`appear` first render never animates). */
  @Local armed: boolean = false;

  aboutToAppear(): void {
    this.mounted = this.show && !this.appear;
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

  private enter(): void {
    this.onBeforeEnter();
    this.mounted = true;
    if (!sparkTransitionSideAnimates(this.name, this.timing(), this.enterEffect)) {
      this.onAfterEnter();
    }
  }

  private leave(): void {
    this.onBeforeLeave();
    this.mounted = false;
    if (!sparkTransitionSideAnimates(this.name, this.timing(), this.leaveEffect)) {
      this.onAfterLeave();
    }
  }

  @Monitor('show')
  syncShow(): void {
    if (!this.armed) {
      return;
    }
    if (this.show && !this.mounted) {
      this.enter();
    } else if (!this.show && this.mounted) {
      this.leave();
    }
  }

  private finished(isIn: boolean): void {
    // instant sides already fired their hook synchronously
    if (!sparkTransitionSideAnimates(this.name, this.timing(), isIn ? this.enterEffect : this.leaveEffect)) {
      return;
    }
    if (isIn) {
      this.onAfterEnter();
    } else {
      this.onAfterLeave();
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.mounted) {
        Stack({ alignContent: Alignment.TopStart }) {
          this.content()
        }
        .transition(this.effect(), (isIn: boolean) => this.finished(isIn))
      }
    }
    .onAppear(() => {
      this.armed = true;
      if (this.show && !this.mounted) {
        this.enter();
      }
    })
  }
}
