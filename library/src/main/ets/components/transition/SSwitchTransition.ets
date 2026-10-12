import { SparkAnim, SparkSpeed } from '../../core/SparkAnim';
import { SparkUI } from '../../core/SparkUI';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import {
  SparkTransitionEffectFactory, sparkTransitionEffect, sparkTransitionSideAnimates, sparkTransitionTiming,
  SparkTransitionTiming
} from './SparkTransitionEffect';
import {
  SparkNavDirection, sparkResolveForward, SparkTransitionHistory, SparkTransitionMode, SparkTransitionName
} from './TransitionSpec';

/** Default for the keyed builder slot. */
@Builder
export function sparkEmptyKeyBuilder(key: string) {
}

/** One mounted view: `key` is fixed for its lifetime, so a leaving view keeps rendering its old content. */
export class SparkTransitionSlot {
  readonly id: number;
  readonly key: string;

  constructor(id: number, key: string) {
    this.id = id;
    this.key = key;
  }
}

/**
 * Keyed content switcher (Vue `<Transition mode>` around `<component :is>` / `<RouterView v-slot>`): renders
 * `pageBuilder(current)` and, when `current` changes, animates from the old view to the new one. Both views are
 * mounted only while the transition runs (ForEach keyed slots + `.transition(TransitionEffect.asymmetric(...))`).
 *
 * ```
 * @Local page: string = 'home';
 * @LocalBuilder renderPage(key: string) { if (key === 'home') { HomeView() } else { SettingsView() } }
 * SSwitchTransition({ current: this.page, pageBuilder: this.renderPage, name: 'shared-axis-x',
 *   mode: 'out-in', order: ['home', 'settings'] })
 * ```
 * - `pageBuilder` receives the key; build the view **from that argument** (not from parent state) so the leaving
 *   view keeps its content. Use `@LocalBuilder` so `this` stays the parent.
 * - `mode`: 'default' (simultaneous, views overlap in a Stack), 'out-in' (old leaves, then new enters),
 *   'in-out' (new enters, then old leaves).
 * - `navDirection` (named so because `direction` is a universal attribute): 'forward' | 'back' | 'auto'. 'auto'
 *   compares `index` (numeric, e.g. a tab index), then positions in `order`, then the visit history (returning to
 *   the previous key = back). Direction-aware presets (slide-*, zoom, shared-axis-*) reverse on back.
 * - Lifecycle events receive the key: onBeforeEnter / onAfterEnter / onBeforeLeave / onAfterLeave.
 * - `clipContent` (default true) clips sliding views to the switcher's bounds.
 */
@ComponentV2
export struct SSwitchTransition {
  @Param current: string = '';
  @BuilderParam pageBuilder: (key: string) => void = sparkEmptyKeyBuilder;
  @Param name: SparkTransitionName = 'fade';
  @Param mode: SparkTransitionMode = 'default';
  @Param navDirection: SparkNavDirection = 'auto';
  /** Ordered keys for `navDirection: 'auto'` (later = forward). */
  @Param order: string[] = [];
  /** Numeric position of `current` for `navDirection: 'auto'` (-1 = unused). */
  @Param index: number = -1;
  @Param appear: boolean = false;
  @Param distance: string = '100%';
  @Param clipContent: boolean = true;
  @Param motionKey: string = 'transition';
  @Param speed: SparkSpeed = 'normal';
  @Param duration: number = -1;
  @Param ease: string = '';
  @Param enterEffect: SparkTransitionEffectFactory | undefined = undefined;
  @Param leaveEffect: SparkTransitionEffectFactory | undefined = undefined;
  @Event onBeforeEnter: (key: string) => void = () => {
  };
  @Event onAfterEnter: (key: string) => void = () => {
  };
  @Event onBeforeLeave: (key: string) => void = () => {
  };
  @Event onAfterLeave: (key: string) => void = () => {
  };
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local slots: SparkTransitionSlot[] = [];
  @Local forward: boolean = true;
  @Local armed: boolean = false;
  private seq: number = 0;
  /** Key of the latest target (what `current` last resolved to). */
  private target: string = '';
  private targetIndex: number = -1;
  private history: SparkTransitionHistory = new SparkTransitionHistory();
  /** 'out-in': slot id whose leave we wait for (-1 = none). */
  private awaitLeave: number = -1;
  /** 'in-out': slot id whose enter we wait for (-1 = none). */
  private awaitEnter: number = -1;

  aboutToAppear(): void {
    this.target = this.current;
    this.targetIndex = this.index;
    this.history.reset(this.current);
    if (!this.appear) {
      this.slots = [this.slot(this.current)];
    }
  }

  private slot(key: string): SparkTransitionSlot {
    this.seq++;
    return new SparkTransitionSlot(this.seq, key);
  }

  private timing(): SparkTransitionTiming {
    return sparkTransitionTiming(this.theme, this.motionKey, this.speed, this.duration, this.ease);
  }

  private enterAnimates(): boolean {
    return sparkTransitionSideAnimates(this.name, this.timing(), this.enterEffect);
  }

  private leaveAnimates(): boolean {
    return sparkTransitionSideAnimates(this.name, this.timing(), this.leaveEffect);
  }

  private effect(): TransitionEffect {
    if (!this.armed) {
      return TransitionEffect.IDENTITY;
    }
    return sparkTransitionEffect(this.name, this.forward, this.distance, this.timing(), this.enterEffect,
      this.leaveEffect);
  }

  @Monitor('current', 'index')
  syncCurrent(): void {
    if (!this.armed || this.current === this.target) {
      this.targetIndex = this.index;
      return;
    }
    const prev = this.target;
    const fwd = sparkResolveForward(this.navDirection, prev, this.current, this.order, this.targetIndex, this.index,
      this.history);
    this.target = this.current;
    this.targetIndex = this.index;
    // Publish the direction first and flush it (applySync), so views about to be removed already carry the
    // leave effect for this direction: a removed node keeps the effect it had when it left the tree.
    if (fwd !== this.forward) {
      SparkAnim.commit(() => {
        this.forward = fwd;
      });
    }
    this.go(this.current);
  }

  private go(next: string): void {
    if (this.mode === 'out-in') {
      this.goOutIn(next);
    } else if (this.mode === 'in-out') {
      this.goInOut(next);
    } else {
      this.removeAll();
      this.mount(next);
    }
  }

  /** Remove every mounted view (leave transitions start); returns the id of the last one removed (-1 = none). */
  private removeAll(): number {
    const old = this.slots;
    if (old.length === 0) {
      return -1;
    }
    old.forEach((s: SparkTransitionSlot) => this.onBeforeLeave(s.key));
    this.slots = [];
    if (!this.leaveAnimates()) {
      old.forEach((s: SparkTransitionSlot) => this.onAfterLeave(s.key));
      return -1;
    }
    return old[old.length - 1].id;
  }

  private mount(key: string): SparkTransitionSlot {
    const s = this.slot(key);
    this.onBeforeEnter(key);
    const next: SparkTransitionSlot[] = this.slots.slice();
    next.push(s);
    this.slots = next;
    if (!this.enterAnimates()) {
      this.onAfterEnter(key);
    }
    return s;
  }

  private goOutIn(next: string): void {
    if (this.awaitLeave >= 0) {
      return; // a leave is running: the latest `target` is mounted when it finishes
    }
    const leaving = this.removeAll();
    if (leaving >= 0) {
      this.awaitLeave = leaving;
    } else {
      this.mount(next);
    }
  }

  private goInOut(next: string): void {
    const s = this.mount(next);
    if (this.enterAnimates()) {
      this.awaitEnter = s.id;
    } else {
      this.dropAllBut(s.id);
    }
  }

  /** Remove every view except `id` (used by 'in-out' once the new view has entered). */
  private dropAllBut(id: number): void {
    const keep: SparkTransitionSlot[] = this.slots.filter((s: SparkTransitionSlot) => s.id === id);
    const gone: SparkTransitionSlot[] = this.slots.filter((s: SparkTransitionSlot) => s.id !== id);
    if (gone.length === 0) {
      return;
    }
    gone.forEach((s: SparkTransitionSlot) => this.onBeforeLeave(s.key));
    this.slots = keep;
    if (!this.leaveAnimates()) {
      gone.forEach((s: SparkTransitionSlot) => this.onAfterLeave(s.key));
    }
  }

  private finished(s: SparkTransitionSlot, isIn: boolean): void {
    if (isIn) {
      if (!this.enterAnimates()) {
        return;
      }
      this.onAfterEnter(s.key);
      if (s.id === this.awaitEnter) {
        this.awaitEnter = -1;
        this.dropAllBut(s.id);
      }
      return;
    }
    if (!this.leaveAnimates()) {
      return;
    }
    this.onAfterLeave(s.key);
    if (s.id === this.awaitLeave) {
      this.awaitLeave = -1;
      this.mount(this.target);
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.slots, (s: SparkTransitionSlot) => {
        Stack({ alignContent: Alignment.TopStart }) {
          this.pageBuilder(s.key)
        }
        .width('100%')
        .transition(this.effect(), (isIn: boolean) => this.finished(s, isIn))
      }, (s: SparkTransitionSlot) => String(s.id))
    }
    .width('100%')
    .clip(this.clipContent)
    .onAppear(() => {
      this.armed = true;
      if (this.slots.length === 0) {
        this.mount(this.target);
      }
    })
  }
}

/**
 * Page-level `SSwitchTransition` (Vue `<RouterView v-slot="{ Component }"><Transition :name>`): direction-aware
 * Material shared-axis X by default, history-based back detection unless `order` / `index` is given.
 * ```
 * SPageTransition({ current: this.page, pageBuilder: this.renderPage, order: PAGE_IDS })
 * ```
 */
@ComponentV2
export struct SPageTransition {
  @Param current: string = '';
  @BuilderParam pageBuilder: (key: string) => void = sparkEmptyKeyBuilder;
  @Param name: SparkTransitionName = 'shared-axis-x';
  @Param mode: SparkTransitionMode = 'default';
  @Param navDirection: SparkNavDirection = 'auto';
  @Param order: string[] = [];
  @Param index: number = -1;
  @Param appear: boolean = false;
  @Param distance: string = '100%';
  @Param clipContent: boolean = true;
  @Param motionKey: string = 'page-transition';
  @Param speed: SparkSpeed = 'normal';
  @Param duration: number = -1;
  @Param ease: string = '';
  @Param enterEffect: SparkTransitionEffectFactory | undefined = undefined;
  @Param leaveEffect: SparkTransitionEffectFactory | undefined = undefined;
  @Event onBeforeEnter: (key: string) => void = () => {
  };
  @Event onAfterEnter: (key: string) => void = () => {
  };
  @Event onBeforeLeave: (key: string) => void = () => {
  };
  @Event onAfterLeave: (key: string) => void = () => {
  };

  build() {
    Column() {
      SSwitchTransition({
        current: this.current,
        pageBuilder: this.pageBuilder,
        name: this.name,
        mode: this.mode,
        navDirection: this.navDirection,
        order: this.order,
        index: this.index,
        appear: this.appear,
        distance: this.distance,
        clipContent: this.clipContent,
        motionKey: this.motionKey,
        speed: this.speed,
        duration: this.duration,
        ease: this.ease,
        enterEffect: this.enterEffect,
        leaveEffect: this.leaveEffect,
        onBeforeEnter: (k: string) => this.onBeforeEnter(k),
        onAfterEnter: (k: string) => this.onAfterEnter(k),
        onBeforeLeave: (k: string) => this.onBeforeLeave(k),
        onAfterLeave: (k: string) => this.onAfterLeave(k)
      })
    }
    .width('100%')
  }
}
