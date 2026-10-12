import {
  SButton, SparkTheme, SparkTransitionEnv, SparkTransitionMode, SparkTransitionName, SparkUI, SPageTransition,
  SSwitchTransition, STransition, STransitionGroup, SToggleGroup, SToggleGroupItem
} from '@sparkui/core';
import { DemoBlock, DemoCaption, DocHeader, DocSection } from '../shell/DocKit';

const SHOW_PRESETS: string[] = ['fade', 'slide-down', 'slide-up', 'scale', 'zoom'];
const SWITCH_PRESETS: string[] = ['fade', 'slide-left', 'slide-up', 'scale', 'zoom', 'fade-through', 'shared-axis-x',
  'shared-axis-y', 'shared-axis-z', 'none'];
const VIEWS: string[] = ['inbox', 'drafts', 'sent'];
const STEPS: string[] = ['cart', 'shipping', 'payment', 'done'];

function stepTitle(key: string): string {
  return key.length > 0 ? key.substring(0, 1).toUpperCase() + key.substring(1) : key;
}

/** A coloured stand-in "page" for the demos. */
@ComponentV2
struct DemoPane {
  @Param title: string = '';
  @Param body: string = '';
  @Param tone: number = 0;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  private bg(): string {
    const c = this.theme.colors;
    return this.tone % 3 === 0 ? c.muted : (this.tone % 3 === 1 ? c.accent : c.secondary);
  }

  build() {
    Column({ space: 6 }) {
      Text(this.title)
        .fontSize(this.theme.text.lg)
        .fontWeight(this.theme.text.weightSemibold)
        .fontColor(this.theme.colors.foreground)
      Text(this.body)
        .fontSize(this.theme.text.sm)
        .lineHeight(this.theme.text.leadingSm)
        .fontColor(this.theme.colors.mutedForeground)
    }
    .width('100%')
    .height(120)
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.bg())
    .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg })
  }
}

/** A list row for the TransitionGroup demo. */
@ComponentV2
struct DemoRow {
  @Param text: string = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Row() {
      Text(this.text).fontSize(this.theme.text.sm).fontColor(this.theme.colors.foreground)
    }
    .width('100%')
    .height(40)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.theme.colors.card)
    .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusMd })
  }
}

// ------------------------------------------------------------------------------------------------ code

const SHOW_CODE = `@Local open: boolean = true;

SButton({ text: 'Toggle' }).onClick(() => this.open = !this.open)
STransition({ show: this.open, name: 'slide-down', distance: '24vp',
  onAfterEnter: () => { ... }, onAfterLeave: () => { ... } }) {
  DemoPane({ title: 'Hello', body: '...' })
}`;

const SWITCH_CODE = `@Local view: string = 'inbox';

@LocalBuilder
renderView(key: string) {
  // build from the key argument, so the leaving view keeps its own content
  DemoPane({ title: key, body: '...' })
}

SSwitchTransition({
  current: this.view,
  pageBuilder: this.renderView,
  name: 'shared-axis-x',      // fade | slide-* | scale | zoom | fade-through | shared-axis-x/y/z | none
  mode: 'out-in',             // 'default' (simultaneous) | 'out-in' | 'in-out'
  order: ['inbox', 'drafts', 'sent'],   // navDirection 'auto': later key = forward
  onBeforeLeave: (k: string) => { ... },
  onAfterEnter: (k: string) => { ... }
})`;

const PAGE_CODE = `// Vue: <RouterView v-slot="{ Component }"><Transition name="slide-left">…
@Local step: number = 0;

@LocalBuilder
renderStep(key: string) { DemoPane({ title: key }) }

SPageTransition({
  current: STEPS[this.step],
  index: this.step,          // or order: STEPS, or neither (visit history: going back = back)
  pageBuilder: this.renderStep,
  name: 'slide-left'         // default 'shared-axis-x'
})
SButton({ text: 'Back' }).onClick(() => this.step--)   // reverses the slide
SButton({ text: 'Next' }).onClick(() => this.step++)

// gallery shell (pages/Index.ets): animate between doc pages
@LocalBuilder renderPage(key: string) { DocContent({ page: key }) }
SPageTransition({ current: this.page, pageBuilder: this.renderPage, order: NAV_ORDER, name: 'fade-through' })`;

const CUSTOM_CODE = `STransition({
  show: this.open,
  duration: 600,                      // per-instance override (ms); motion off still wins
  ease: 'spring(0.5, 0.7)',
  enterEffect: (env: SparkTransitionEnv) => TransitionEffect.rotate({ z: 1, angle: -90 })
    .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 })).combine(TransitionEffect.OPACITY),
  leaveEffect: (env: SparkTransitionEnv) => TransitionEffect.translate({ x: 120 })
    .combine(TransitionEffect.OPACITY)
}) { ... }

// theme: --motion-transition-duration: 300ms; --motion-transition-ease: ease-out;
// --motion-page-transition-*, --motion-transition-group-*; --motion-enabled: false → instant`;

const GROUP_CODE = `@Local ids: string[] = ['Apple', 'Banana', 'Cherry'];

@LocalBuilder
renderItem(key: string) { DemoRow({ text: key }) }

STransitionGroup({ items: this.ids, itemBuilder: this.renderItem, name: 'slide-left', distance: '40vp', gap: 8 })
// assign a new array: insert / remove animate, the other rows glide to their new place
this.ids = [...];`;

// ------------------------------------------------------------------------------------------------ doc

@ComponentV2
export struct TransitionDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local open: boolean = true;
  @Local showPreset: string = 'fade';
  @Local showLog: string = 'shown';
  @Local view: string = 'inbox';
  @Local switchPreset: string = 'shared-axis-x';
  @Local mode: string = 'out-in';
  @Local switchLog: string = '—';
  @Local step: number = 0;
  @Local customOpen: boolean = true;
  @Local ids: string[] = ['Apple', 'Banana', 'Cherry'];
  private nextFruit: number = 0;

  @LocalBuilder
  renderView(key: string) {
    DemoPane({ title: stepTitle(key), body: `View '${key}' — built from the key passed to pageBuilder.`,
      tone: VIEWS.indexOf(key) })
  }

  @LocalBuilder
  renderStep(key: string) {
    DemoPane({ title: `Step ${STEPS.indexOf(key) + 1}: ${stepTitle(key)}`, body: 'Next slides left, Back reverses.',
      tone: STEPS.indexOf(key) })
  }

  @LocalBuilder
  renderItem(key: string) {
    DemoRow({ text: key })
  }

  private addFruit(): void {
    const pool: string[] = ['Date', 'Elderberry', 'Fig', 'Grape', 'Kiwi', 'Lemon', 'Mango'];
    const name = pool[this.nextFruit % pool.length] + (this.nextFruit >= pool.length ?
      ` ${Math.floor(this.nextFruit / pool.length) + 1}` : '');
    this.nextFruit++;
    const next = this.ids.slice();
    next.splice(Math.min(1, next.length), 0, name);
    this.ids = next;
  }

  private removeFruit(): void {
    if (this.ids.length > 0) {
      const next = this.ids.slice();
      next.splice(Math.floor(next.length / 2), 1);
      this.ids = next;
    }
  }

  private shuffleFruit(): void {
    const next = this.ids.slice();
    for (let i = next.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const t = next[i];
      next[i] = next[j];
      next[j] = t;
    }
    this.ids = next;
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Transition',
        lead: "Vue-style <Transition>, keyed switchers and <TransitionGroup>, built on ArkUI component " +
          'transitions (TransitionEffect.asymmetric + if / ForEach keys). Timing comes from SparkAnim: ' +
          '--motion-transition-* is configurable and motion off makes every switch instant.'
      })

      DocSection({ title: 'Show / hide', description: 'STransition mounts and removes its content with `show` ' +
        '(v-if). Lifecycle events: onBeforeEnter, onAfterEnter, onBeforeLeave, onAfterLeave.' })
      DemoBlock({ code: SHOW_CODE, centered: false }) {
        Column({ space: 12 }) {
          SToggleGroup({ type: 'single', sizing: 'sm', variant: 'outline', deselectable: false, wrap: true,
            value: [this.showPreset], onValueChange: (v: string[]) => {
              if (v.length > 0) {
                this.showPreset = v[0];
              }
            } }) {
            ForEach(SHOW_PRESETS, (p: string) => {
              SToggleGroupItem({ value: p, text: p })
            }, (p: string) => p)
          }
          SButton({ text: this.open ? 'Hide' : 'Show', variant: 'outline', sizing: 'sm' }).onClick(() => {
            this.open = !this.open;
          })
          Column() {
            STransition({ show: this.open, name: this.showPreset as SparkTransitionName, distance: '24vp',
              onBeforeEnter: () => {
                this.showLog = 'entering…';
              },
              onAfterEnter: () => {
                this.showLog = 'shown (onAfterEnter)';
              },
              onBeforeLeave: () => {
                this.showLog = 'leaving…';
              },
              onAfterLeave: () => {
                this.showLog = 'hidden (onAfterLeave)';
              } }) {
              DemoPane({ title: 'Hello there', body: 'This panel is inserted and removed with a transition.' })
            }
          }
          .width('100%')
          .constraintSize({ minHeight: 120 })
          DemoCaption({ text: this.showLog })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      DocSection({ title: 'Switch transition', description: 'SSwitchTransition renders pageBuilder(current) and ' +
        'animates between the old and the new view; both are mounted only while the transition runs. ' +
        "mode 'out-in' / 'in-out' sequences them, 'default' runs both at once. Going to an earlier key in " +
        '`order` reverses direction-aware presets.' })
      DemoBlock({ code: SWITCH_CODE, centered: false }) {
        Column({ space: 12 }) {
          SToggleGroup({ type: 'single', sizing: 'sm', variant: 'outline', deselectable: false, wrap: true,
            value: [this.switchPreset], onValueChange: (v: string[]) => {
              if (v.length > 0) {
                this.switchPreset = v[0];
              }
            } }) {
            ForEach(SWITCH_PRESETS, (p: string) => {
              SToggleGroupItem({ value: p, text: p })
            }, (p: string) => p)
          }
          SToggleGroup({ type: 'single', sizing: 'sm', deselectable: false, value: [this.mode],
            onValueChange: (v: string[]) => {
              if (v.length > 0) {
                this.mode = v[0];
              }
            } }) {
            SToggleGroupItem({ value: 'default', text: 'simultaneous' })
            SToggleGroupItem({ value: 'out-in', text: 'out-in' })
            SToggleGroupItem({ value: 'in-out', text: 'in-out' })
          }
          SToggleGroup({ type: 'single', variant: 'outline', deselectable: false, value: [this.view],
            onValueChange: (v: string[]) => {
              if (v.length > 0) {
                this.view = v[0];
              }
            } }) {
            SToggleGroupItem({ value: 'inbox', text: 'Inbox', icon: 'inbox' })
            SToggleGroupItem({ value: 'drafts', text: 'Drafts', icon: 'file-text' })
            SToggleGroupItem({ value: 'sent', text: 'Sent', icon: 'send' })
          }
          SSwitchTransition({
            current: this.view,
            pageBuilder: this.renderView,
            name: this.switchPreset as SparkTransitionName,
            mode: this.mode as SparkTransitionMode,
            order: VIEWS,
            onBeforeLeave: (k: string) => {
              this.switchLog = `leave '${k}'…`;
            },
            onAfterEnter: (k: string) => {
              this.switchLog = `entered '${k}'`;
            }
          })
          DemoCaption({ text: this.switchLog })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      DocSection({ title: 'Page transition', description: 'SPageTransition is the page-level switcher ' +
        "(RouterView + Transition): shared-axis X by default, direction from `index`, `order` or the visit " +
        'history. Wrap the gallery\'s DocContent the same way to animate between doc pages.' })
      DemoBlock({ code: PAGE_CODE, centered: false }) {
        Column({ space: 12 }) {
          SPageTransition({ current: STEPS[this.step], index: this.step, pageBuilder: this.renderStep,
            name: 'slide-left' })
          Row({ space: 8 }) {
            SButton({ text: 'Back', icon: 'arrow-left', variant: 'outline', sizing: 'sm', disabled: this.step === 0 })
              .onClick(() => {
                if (this.step > 0) {
                  this.step--;
                }
              })
            SButton({ text: 'Next', icon: 'arrow-right', sizing: 'sm', disabled: this.step === STEPS.length - 1 })
              .onClick(() => {
                if (this.step < STEPS.length - 1) {
                  this.step++;
                }
              })
          }
          DemoCaption({ text: `step ${this.step + 1} / ${STEPS.length}` })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      DocSection({ title: 'Custom effects & timing', description: 'enterEffect / leaveEffect take any ' +
        'TransitionEffect (inheriting the resolved duration and curve); duration and ease override the motion ' +
        'key per instance.' })
      DemoBlock({ code: CUSTOM_CODE, centered: false }) {
        Column({ space: 12 }) {
          SButton({ text: this.customOpen ? 'Hide' : 'Show', variant: 'outline', sizing: 'sm' }).onClick(() => {
            this.customOpen = !this.customOpen;
          })
          Column() {
            STransition({
              show: this.customOpen,
              duration: 600,
              ease: 'spring(0.5, 0.7)',
              enterEffect: (env: SparkTransitionEnv) => TransitionEffect.rotate({ z: 1, angle: -90 })
                .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 })).combine(TransitionEffect.OPACITY),
              leaveEffect: (env: SparkTransitionEnv) => TransitionEffect.translate({ x: 120 })
                .combine(TransitionEffect.OPACITY)
            }) {
              DemoPane({ title: 'Custom', body: 'Rotates in, slides out.', tone: 1 })
            }
          }
          .width('100%')
          .constraintSize({ minHeight: 120 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      DocSection({ title: 'Transition group', description: 'STransitionGroup animates inserted and removed ' +
        'items; the remaining items move to their new positions with a layout animation (Vue FLIP move).' })
      DemoBlock({ code: GROUP_CODE, centered: false }) {
        Column({ space: 12 }) {
          Row({ space: 8 }) {
            SButton({ text: 'Add', icon: 'plus', sizing: 'sm' }).onClick(() => this.addFruit())
            SButton({ text: 'Remove', icon: 'minus', variant: 'outline', sizing: 'sm' })
              .onClick(() => this.removeFruit())
            SButton({ text: 'Shuffle', icon: 'refresh-cw', variant: 'outline', sizing: 'sm' })
              .onClick(() => this.shuffleFruit())
          }
          STransitionGroup({ items: this.ids, itemBuilder: this.renderItem, name: 'slide-left', distance: '40vp',
            gap: 8 })
          DemoCaption({ text: `${this.ids.length} items` })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
