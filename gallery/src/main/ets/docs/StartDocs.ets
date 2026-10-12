import { LengthMetrics } from '@kit.ArkUI';
import {
  SButton, SCodeBlock, SIcon, SparkAccentName, SparkColor, SparkLayoutContext, SparkPresetName, SparkTheme, SparkUI,
  SPARK_ACCENTS, SPARK_PRESETS, accentCss, SparkContainer, ThemeCssParser, ThemeResolver, resolveSparkLayout,
  SparkContext, STabs, STabsList, STabsTrigger, STabsContent, SAccordion, SAccordionItem, SAccordionTrigger,
  SAccordionContent, SToggleGroup, SToggleGroupItem, SparkThemeMode
} from '@sparkui/core';
import { DemoBlock, DocHeader, DocSection } from '../shell/DocKit';

const INSTALL = `ohpm install @sparkui/core`;

const USAGE = `import { SparkProvider, SButton } from '@sparkui/core';

@Entry
@ComponentV2
struct Index {
  build() {
    Stack() {                       // @Entry root must be a system container
      SparkProvider() {             // theme + layout context for the page
        Column({ space: 12 }) {
          SButton({ text: 'Get started' })
            .onClick(() => console.info('clicked'))
        }
      }
    }
  }
}`;

@ComponentV2
export struct IntroDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  @Builder
  feature(icon: string, title: string, text: string) {
    Column({ space: 6 }) {
      SIcon({ name: icon, sizing: 20 })
      Text(title).fontSize(this.theme.text.sm).fontWeight(this.theme.text.weightSemibold)
        .fontColor(this.theme.colors.foreground)
      Text(text).fontSize(this.theme.text.sm).lineHeight(this.theme.text.leadingSm)
        .fontColor(this.theme.colors.mutedForeground)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .width(260)
    .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg })
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Introduction',
        lead: 'SparkUI is a refined, token-driven ArkTS component library for HarmonyOS — the shadcn-vue experience, ' +
          'native to ArkUI, with an adaptive layout system for phones, foldables, tablets and 2-in-1s.'
      })
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(12), cross: LengthMetrics.vp(12) } }) {
        this.feature('palette', 'Tokens all the way down',
          'Paste a shadcn / tweakcn theme. oklch, hsl, rgb and hex are converted precisely; switch at runtime.')
        this.feature('layout-dashboard', 'One context, every device',
          'Width / height classes, fold posture and input modality drive component decisions.')
        this.feature('sparkles', 'Beautiful by default',
          'Every part is styled out of the box and still overridable with AttributeModifier.')
      }
      DocSection({ title: 'Installation' })
      SCodeBlock({ code: INSTALL, language: 'bash' })
      DocSection({ title: 'Usage', description: 'Wrap each page in SparkProvider, then use any S-prefixed component.' })
      SCodeBlock({ code: USAGE, language: 'arkts', title: 'Index.ets' })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

const RADII: number[] = [0, 0.3, 0.5, 0.625, 0.75, 1];
const EASES: string[] = ['standard', 'spring', 'linear', 'slow'];

/** [ease, duration ms] for the motion presets of the demo */
function easeSpec(name: string): string[] {
  switch (name) {
    case 'spring':
      return ['spring(0.42, 0.78)', '420'];
    case 'linear':
      return ['linear', '200'];
    case 'slow':
      return ['ease-in-out', '700'];
    default:
      return ['standard', '200'];
  }
}

function accentSwatch(name: SparkAccentName): string {
  if (name === 'none') {
    return '#FF171717';
  }
  const t = new SparkTheme();
  ThemeResolver.apply(ThemeCssParser.parse(accentCss(name)), false, 'compact', t);
  return t.colors.primary;
}

@ComponentV2
export struct ThemingDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local radius: number = 0.625;
  @Local motionOn: boolean = true;
  @Local ease: string = 'standard';
  private swatches: string[] = SPARK_ACCENTS.map((a: SparkAccentName) => accentSwatch(a));

  @Builder
  label(text: string) {
    Text(text)
      .fontSize(this.theme.text.sm)
      .fontWeight(this.theme.text.weightMedium)
      .fontColor(this.theme.colors.foreground)
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Theming',
        lead: 'Every colour, radius, spacing and shadow comes from tokens. Pick a base gray, an accent colour and a ' +
          'radius — everything below updates live, including native ArkUI components.'
      })

      // Single-select toggle groups: one indicator slides to the new choice while the theme colours transition.
      this.label('Mode')
      SToggleGroup({ type: 'single', variant: 'outline', deselectable: false, value: [SparkUI.themes.mode],
        onValueChange: (v: string[]) => {
          if (v.length > 0) {
            SparkUI.themes.setMode(v[0] as SparkThemeMode);
          }
        } }) {
        SToggleGroupItem({ value: 'light', text: 'Light', icon: 'sun' })
        SToggleGroupItem({ value: 'dark', text: 'Dark', icon: 'moon' })
        SToggleGroupItem({ value: 'system', text: 'System', icon: 'monitor' })
      }

      this.label('Accent colour')
      SToggleGroup({ type: 'single', sizing: 'sm', spacing: 8, wrap: true, deselectable: false,
        value: [SparkUI.themes.accent],
        onValueChange: (v: string[]) => {
          if (v.length > 0) {
            SparkUI.themes.useAccent(v[0] as SparkAccentName);
          }
        } }) {
        ForEach(SPARK_ACCENTS, (a: SparkAccentName, i: number) => {
          SToggleGroupItem({ value: a, label: a }) {
            Row({ space: 8 }) {
              Column()
                .width(14)
                .height(14)
                .borderRadius(7)
                .backgroundColor(a === 'none' ? this.theme.colors.foreground : this.swatches[i])
              Text(a === 'none' ? 'Default' : a.charAt(0).toUpperCase() + a.substring(1))
                .fontSize(this.theme.text.sm)
                .fontColor(this.theme.colors.foreground)
            }
            .padding({ left: 4, right: 4 })
          }
        }, (a: SparkAccentName) => a)
      }

      this.label('Base gray')
      SToggleGroup({ type: 'single', sizing: 'sm', spacing: 8, wrap: true, deselectable: false,
        value: [SparkUI.themes.preset],
        onValueChange: (v: string[]) => {
          if (v.length > 0) {
            SparkUI.themes.usePreset(v[0] as SparkPresetName);
          }
        } }) {
        ForEach(SPARK_PRESETS, (p: SparkPresetName) => {
          SToggleGroupItem({ value: p, text: p })
        }, (p: SparkPresetName) => p)
      }
      Text('Base grays only shift the hue of neutrals (backgrounds, borders, muted text) — subtle by design, exactly ' +
        'like shadcn. Accent colours change primary and ring.')
        .fontSize(this.theme.text.xs)
        .fontColor(this.theme.colors.mutedForeground)

      this.label('Radius')
      SToggleGroup({ type: 'single', sizing: 'sm', spacing: 8, wrap: true, deselectable: false,
        value: [String(this.radius)],
        onValueChange: (v: string[]) => {
          if (v.length > 0) {
            this.radius = Number(v[0]);
            SparkUI.themes.setVariable('--radius', `${v[0]}rem`);
          }
        } }) {
        ForEach(RADII, (r: number) => {
          SToggleGroupItem({ value: String(r), text: String(r) })
        }, (r: number) => String(r))
      }

      this.label('Motion')
      SToggleGroup({ type: 'single', sizing: 'sm', variant: 'outline', deselectable: false,
        value: [this.motionOn ? 'on' : 'off'],
        onValueChange: (v: string[]) => {
          if (v.length > 0) {
            this.motionOn = v[0] === 'on';
            SparkUI.themes.setMotionEnabled(this.motionOn);
          }
        } }) {
        SToggleGroupItem({ value: 'on', text: 'On' })
        SToggleGroupItem({ value: 'off', text: 'Off' })
      }
      SToggleGroup({ type: 'single', sizing: 'sm', spacing: 8, wrap: true, deselectable: false, value: [this.ease],
        onValueChange: (v: string[]) => {
          if (v.length === 0) {
            return;
          }
          this.ease = v[0];
          const spec = easeSpec(v[0]);
          ['tabs', 'accordion', 'collapsible', 'toggle-group', 'button', 'dialog', 'popover', 'menu', 'select',
            'sheet'].forEach((k: string) => {
            SparkUI.themes.setMotion(k, { ease: spec[0], duration: Number(spec[1]) });
          });
        } }) {
        ForEach(EASES, (e: string) => {
          SToggleGroupItem({ value: e, text: e })
        }, (e: string) => e)
      }
      Text('Every animated component has a motion key. Configure it like a CSS transition — ' +
        'SparkUI.themes.setMotion("accordion", { duration: 320, ease: "spring(0.45, 0.85)" }) — or in the ' +
        'theme file as --motion-accordion-duration / --motion-accordion-ease. Pressed states never animate.')
        .fontSize(this.theme.text.xs)
        .fontColor(this.theme.colors.mutedForeground)
      Column({ space: 12 }) {
        STabs({ defaultValue: 'one' }) {
          STabsList() {
            STabsTrigger({ value: 'one', text: 'Overview' })
            STabsTrigger({ value: 'two', text: 'Analytics' })
            STabsTrigger({ value: 'three', text: 'Reports' })
          }
        }
        SAccordion({ type: 'single', collapsible: true }) {
          SAccordionItem({ value: 'a' }) {
            SAccordionTrigger({ text: 'Try the motion presets above' })
            SAccordionContent() {
              Text('The height, the chevron and the tab indicator use the configured duration and curve.')
                .fontSize(this.theme.text.sm)
                .fontColor(this.theme.colors.foreground)
            }
          }
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: 420 })

      DocSection({ title: 'Preview' })
      Column({ space: 12 }) {
        Text('Create an account')
          .fontSize(this.theme.text.lg)
          .fontWeight(this.theme.text.weightSemibold)
          .fontColor(this.theme.colors.cardForeground)
        Text('Enter your email below to create your account.')
          .fontSize(this.theme.text.sm)
          .fontColor(this.theme.colors.mutedForeground)
        TextInput({ placeholder: 'm@example.com' })
        Row({ space: 12 }) {
          Toggle({ type: ToggleType.Switch, isOn: true })
          Text('Native Toggle follows the accent').fontSize(this.theme.text.sm)
            .fontColor(this.theme.colors.foreground)
        }

        Row({ space: 8 }) {
          SButton({ text: 'Create account' })
          SButton({ text: 'Cancel', variant: 'outline' })
          SButton({ variant: 'secondary', sizing: 'icon', icon: 'share-2', label: 'Share' })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .padding(24)
      .width('100%')
      .constraintSize({ maxWidth: 420 })
      .backgroundColor(this.theme.colors.card)
      .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusXl })
      .shadow(this.theme.shadows.sm.toOptions())

      DocSection({
        title: 'theme.css',
        description: 'The effective theme in the CSS subset — paste it into any SparkUI app, or import a shadcn / ' +
          'tweakcn export with SparkUI.themes.loadString().'
      })
      SCodeBlock({ code: SparkUI.themes.exportCss(), language: 'css', title: 'theme.css', maxHeight: 360 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

const LAYOUT_CODE = `@Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;

build() {
  if (this.layout.atLeast('expanded')) {
    Row() { /* two panes */ }
  } else {
    Column() { /* single pane */ }
  }
}`;

@ComponentV2
struct ContainerProbe {
  @Consumer('sparkLayout') windowLayout: SparkLayoutContext = SparkUI.layout.root;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local container: SparkLayoutContext | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.container === undefined) {
      this.container = resolveSparkLayout(this.getUIContext(), this.getUniqueId());
    }
  }

  get layout(): SparkLayoutContext {
    return this.container ?? this.windowLayout;
  }

  build() {
    Text(`container widthClass = ${this.layout.widthClass} (${Math.round(this.layout.width)} vp)`)
      .fontSize(this.theme.text.sm)
      .fontColor(this.theme.colors.foreground)
      .padding(12)
      .width('100%')
      .backgroundColor(SparkColor.alpha(this.theme.colors.primary, 0.08))
      .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusMd, style: BorderStyle.Dashed })
  }
}

@ComponentV2
export struct LayoutDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;

  @Builder
  row(k: string, v: string) {
    Row() {
      Text(k).fontSize(this.theme.text.sm).fontColor(this.theme.colors.mutedForeground).width(160)
      Text(v).fontSize(this.theme.text.sm).fontWeight(this.theme.text.weightMedium)
        .fontColor(this.theme.colors.foreground)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: this.theme.colors.border })
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Adaptive Layout',
        lead: 'SparkUI folds window size, fold posture, window mode, safe areas and input modality into a few discrete ' +
          'signals. Components read the nearest context — window or container — and adapt.'
      })
      Row({ space: 8 }) {
        SButton({ text: 'Phone', icon: 'smartphone', sizing: 'sm', variant: 'outline' })
          .onClick(() => SparkUI.layout.simulate(390, 844, 'flat', 'touch', 'fullscreen'))
        SButton({ text: 'Foldable (book)', icon: 'book-open', sizing: 'sm', variant: 'outline' })
          .onClick(() => SparkUI.layout.simulate(840, 900, 'book', 'touch', 'fullscreen'))
        SButton({ text: 'Tablet (tabletop)', icon: 'laptop', sizing: 'sm', variant: 'outline' })
          .onClick(() => SparkUI.layout.simulate(1280, 800, 'tabletop', 'pointer', 'fullscreen'))
        SButton({ text: 'Real window', icon: 'rotate-ccw', sizing: 'sm',
          variant: this.layout.env.simulated ? 'default' : 'ghost' })
          .onClick(() => SparkUI.layout.simulate(undefined, 0, 'flat', 'touch', 'fullscreen'))
      }
      Text('Simulation overrides the context only (the window keeps its size) — enough to exercise adaptive ' +
        'decisions such as the compact navigation of this gallery.')
        .fontSize(this.theme.text.xs)
        .fontColor(this.theme.colors.mutedForeground)
      Column() {
        this.row('widthClass', this.layout.widthClass)
        this.row('heightClass', this.layout.heightClass)
        this.row('posture', this.layout.env.posture)
        this.row('modality', this.layout.env.modality)
        this.row('windowMode', this.layout.env.windowMode)
        this.row('deviceType', this.layout.env.deviceType)
        this.row('safe area', `top ${this.layout.env.safeArea.top} · bottom ${this.layout.env.safeArea.bottom}`)
        this.row('keyboard', `${this.layout.env.keyboardHeight} vp`)
      }
      .width('100%')
      .constraintSize({ maxWidth: 520 })

      DocSection({
        title: 'Container queries',
        description: 'SparkContainer measures itself and provides a local widthClass to its subtree.'
      })
      Row({ space: 12 }) {
        Column() {
          SparkContainer() {
            ContainerProbe()
          }
        }
        .layoutWeight(1)

        Column() {
          SparkContainer() {
            ContainerProbe()
          }
        }
        .width(220)
      }
      .width('100%')

      DocSection({ title: 'Reading the context' })
      SCodeBlock({ code: LAYOUT_CODE, language: 'arkts' })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
