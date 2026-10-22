import { LengthMetrics } from '@kit.ArkUI';
import {
  ButtonVariant, SButton, SCodeBlock, SDialog, SDialogClose, SDialogContent, SDialogDescription, SDialogFooter,
  SDialogHeader, SDialogTitle, SDialogTrigger, SIcon, SPopover, SPopoverContent, SPopoverTrigger, SSheet,
  SSheetContent, SSheetDescription, SSheetFooter, SSheetHeader, SSheetTitle, SSheetTrigger, SSheetClose, SheetSide,
  SparkIcons, SparkTheme, SparkUI, SparkSide, SCard, SCardHeader, SCardTitle, SCardDescription, SCardContent,
  SCardFooter, SCardAction, SBadge, CodeHighlighter, SparkColor
} from '@ospark/sparkui';
import { DemoBlock, DocHeader, DocSection } from '../shell/DocKit';

const space8: FlexSpaceOptions = { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) };

// ------------------------------------------------------------------------------------------------ Button

const BTN_VARIANTS = `SButton({ text: 'Default' })
SButton({ text: 'Secondary', variant: 'secondary' })
SButton({ text: 'Destructive', variant: 'destructive' })
SButton({ text: 'Outline', variant: 'outline' })
SButton({ text: 'Ghost', variant: 'ghost' })
SButton({ text: 'Link', variant: 'link' })`;

const BTN_SIZES = `SButton({ text: 'Small', sizing: 'sm' })
SButton({ text: 'Default' })
SButton({ text: 'Large', sizing: 'lg' })
SButton({ variant: 'outline', sizing: 'icon', icon: 'plus', label: 'Add' })`;

const BTN_STATES = `SButton({ text: 'Login with Email', icon: 'mail' })
SButton({ text: 'Next', variant: 'secondary', iconRight: 'arrow-right' })
SButton({ text: 'Please wait', loading: true })
SButton({ text: 'Disabled', disabled: true })
  .onClick(() => this.save())   // never fires while disabled`;

const BTN_BLOCK = `SButton({ text: 'Continue', block: true })
SButton({ text: 'Sign in with Google', variant: 'outline', icon: 'globe', block: true })
SButton({ text: 'Save changes', loading: this.saving, loadingText: 'Saving…', block: true })`;

const BTN_TOKENS = `// colour tokens use CSS syntax (#RRGGBBAA); theme.colors.* (#AARRGGBB) may be passed as is
SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'pencil', label: 'Edit', tokens: { foreground: '#4169e1' } })
SButton({ variant: 'outline', sizing: 'icon-sm', icon: 'x', label: 'Remove',
  tokens: { radius: 999, foreground: theme.colors.destructive } })
SButton({ text: 'Discard', variant: 'outline', icon: 'circle-x', block: true,
  tokens: { foreground: SparkColor.toCss(theme.colors.destructive) } })`;

@ComponentV2
export struct ButtonDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local taps: number = 0;
  @Local saving: boolean = false;
  private timer: number = -1;
  private variants: ButtonVariant[] = ['default', 'secondary', 'destructive', 'outline', 'ghost', 'link'];

  aboutToDisappear(): void {
    clearTimeout(this.timer);
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({ title: 'Button', lead: 'Displays a button or a component that looks like a button.' })
      DocSection({ title: 'Variants' })
      DemoBlock({ code: BTN_VARIANTS }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: space8 }) {
          ForEach(this.variants, (v: ButtonVariant) => {
            SButton({ text: v.charAt(0).toUpperCase() + v.substring(1), variant: v }).onClick(() => {
              this.taps++;
            })
          }, (v: ButtonVariant) => v)
        }
      }
      Text(`taps: ${this.taps}`).fontSize(this.theme.text.xs).fontColor(this.theme.colors.mutedForeground)
      DocSection({ title: 'Sizes' })
      DemoBlock({ code: BTN_SIZES }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center, space: space8 }) {
          SButton({ text: 'Small', sizing: 'sm' })
          SButton({ text: 'Default' })
          SButton({ text: 'Large', sizing: 'lg' })
          SButton({ variant: 'outline', sizing: 'icon', icon: 'plus', label: 'Add' })
        }
      }
      DocSection({ title: 'Icons & states' })
      DemoBlock({ code: BTN_STATES }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: space8 }) {
          SButton({ text: 'Login with Email', icon: 'mail' })
          SButton({ text: 'Next', variant: 'secondary', iconRight: 'arrow-right' })
          SButton({ text: 'Please wait', loading: true })
          SButton({ text: 'Disabled', disabled: true }).onClick(() => {
            this.taps += 1000;
          })
        }
      }
      DocSection({
        title: 'Block & loading text',
        description: 'block stretches to the parent width; loadingText replaces the label while loading.'
      })
      DemoBlock({ code: BTN_BLOCK }) {
        Column({ space: 8 }) {
          SButton({ text: 'Continue', block: true })
          SButton({ text: 'Sign in with Google', variant: 'outline', icon: 'globe', block: true })
          SButton({ text: 'Save changes', loading: this.saving, loadingText: 'Saving…', block: true })
            .onClick(() => {
              this.saving = true;
              this.timer = setTimeout(() => {
                this.saving = false;
              }, 1500);
            })
        }
        .width('100%')
        .constraintSize({ maxWidth: 320 })
      }
      DocSection({
        title: 'Foreground token',
        description: 'tokens.foreground recolours the label and icons of any variant. Colours use the theme file ' +
          'syntax (CSS #RRGGBBAA); theme.colors values can be passed as they are, other #AARRGGBB strings go ' +
          'through SparkColor.toCss().'
      })
      DemoBlock({ code: BTN_TOKENS }) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'pencil', label: 'Edit', tokens: { foreground: '#4169e1' } })
            SButton({
              variant: 'outline', sizing: 'icon-sm', icon: 'x', label: 'Remove',
              tokens: { radius: 999, foreground: this.theme.colors.destructive }
            })
            SButton({
              variant: 'ghost', sizing: 'icon-sm', icon: 'pencil', label: 'Edit',
              tokens: { foreground: this.theme.colors.primary }
            })
          }
          SButton({
            text: 'Discard', variant: 'outline', icon: 'circle-x', block: true,
            tokens: { foreground: SparkColor.toCss(this.theme.colors.destructive) }
          })
          SButton({
            text: 'Discard (disabled)', variant: 'outline', icon: 'circle-x', block: true, disabled: true,
            tokens: { foreground: this.theme.colors.destructive }
          })
        }
        .width('100%')
        .constraintSize({ maxWidth: 320 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Icons

@ComponentV2
export struct IconsDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local query: string = '';
  private all: string[] = SparkIcons.names();

  @Computed
  get shown(): string[] {
    const q = this.query.trim().toLowerCase();
    return q.length === 0 ? this.all : this.all.filter((n: string) => n.indexOf(q) >= 0);
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Icons',
        lead: `${this.all.length} lucide icons ship with SparkUI. Register more with SparkIcons.register(), or map a ` +
          'name to a HarmonyOS Symbol with SparkIcons.useSymbol().'
      })
      SCodeBlock({ code: `SIcon({ name: 'heart', sizing: 20, color: theme.colors.destructive })`, language: 'arkts' })
      TextInput({ placeholder: 'Search icons…', text: this.query })
        .onChange((v: string) => {
          this.query = v;
        })
        .width('100%')
        .constraintSize({ maxWidth: 360 })
      Flex({ wrap: FlexWrap.Wrap, space: space8 }) {
        ForEach(this.shown, (name: string) => {
          Column({ space: 6 }) {
            SIcon({ name: name, sizing: 22 })
            Text(name)
              .fontSize(10)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(this.theme.colors.mutedForeground)
          }
          .width(88)
          .height(72)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 4, right: 4 })
          .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusMd })
        }, (name: string) => name)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Code

const SAMPLE_TS = `@ComponentV2
export struct ClickCounter {
  @Local count: number = 0; // reactive state

  build() {
    SButton({ text: \`Clicked \${this.count} times\` })
      .onClick(() => this.count++)
  }
}`;

const SAMPLE_CSS = `:root {
  --radius: 0.625rem;
  --primary: oklch(0.205 0 0);
}
.dark {
  --primary: oklch(0.922 0 0);
}
@size(compact) { --spacing: 0.22rem; }`;
const SAMPLE_DIFF = `--- a/Index.ets
+++ b/Index.ets
@@ -1,3 +1,3 @@
 SCodeBlock({
-  code: source, language: 'arkts'
+  code: source, language: 'arkts', highlightLines: [3]
 })`;

const SAMPLE_INI = `; gallery settings
[server]
host = "127.0.0.1"
port = 5555
verbose = true`;

/** A user-defined grammar: registered by name (usable as `language: 'ini'`) and returned for `grammar:`. */
const INI_GRAMMAR = CodeHighlighter.register({
  name: 'ini',
  aliases: ['conf'],
  icon: 'settings',
  rules: [
    { pattern: /\s+/ },
    { token: 'comment', pattern: /[;#][^\n]*/ },
    { token: 'type', pattern: /\[[^\]\n]*\]/ },
    { pattern: /([\w.-]+)([ \t]*)(=)/, captures: ['property', 'plain', 'punctuation'] },
    { token: 'string', pattern: /"[^"\n]*"?/ },
    { token: 'number', pattern: /\d+(?:\.\d+)?/ },
    { token: 'keyword', words: ['true', 'false', 'on', 'off'] },
    { pattern: /[^\s"]+/ }
  ]
});

const INI_GRAMMAR_CODE = `const INI = CodeHighlighter.register({
  name: 'ini',
  aliases: ['conf'],
  rules: [
    { pattern: /\s+/ },
    { token: 'comment', pattern: /[;#][^\n]*/ },
    { token: 'type', pattern: /\[[^\]\n]*\]/ },
    // capture groups that tile the match get one token each
    { pattern: /([\w.-]+)([ \t]*)(=)/, captures: ['property', 'plain', 'punctuation'] },
    { token: 'string', pattern: /"[^"\n]*"?/ },
    { token: 'number', pattern: /\d+(?:\.\d+)?/ },
    { token: 'keyword', words: ['true', 'false', 'on', 'off'] },
    { pattern: /[^\s"]+/ }
  ]
});

SCodeBlock({ code: source, grammar: INI })   // or language: 'ini' / 'conf'`;

/** Derived from a built-in: extra keywords, PascalCase "type" heuristic switched off. */
const MY_ARKTS = CodeHighlighter.extend('arkts', { name: 'arkts+', keywords: ['observe', 'emit'], exclude: ['type'] });

const MY_ARKTS_CODE = `const MY_ARKTS = CodeHighlighter.extend('arkts', {
  name: 'arkts+',
  keywords: ['observe', 'emit'],
  exclude: ['type']
});

observe Counter(() => emit('changed'))`;

const SAMPLE_JSON = `{
  "root": { "--primary": "#171717", "--radius": "0.5rem" },
  "dark": { "--primary": "#e5e5e5" },
  "sizes": { "compact": { "--spacing": "3.5px" } }
}`;

@ComponentV2
export struct CodeDoc {
  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Code Block',
        lead: 'Highlighted code with line numbers, highlighted lines and a copy button. Built-in languages: ' +
          'ArkTS / TypeScript, CSS, JSON, Bash, HTML / XML, Python, Diff — and your own grammars.'
      })
      SCodeBlock({ code: `SCodeBlock({ code: source, language: 'arkts', title: 'ClickCounter.ets' })`, language: 'arkts',
        showLineNumbers: false })
      DocSection({ title: 'ArkTS' })
      SCodeBlock({ code: SAMPLE_TS, language: 'arkts', title: 'ClickCounter.ets' })
      DocSection({ title: 'CSS theme' })
      SCodeBlock({ code: SAMPLE_CSS, language: 'css', title: 'theme.css' })
      DocSection({ title: 'JSON theme' })
      SCodeBlock({ code: SAMPLE_JSON, language: 'json', title: 'theme.json' })
      DocSection({ title: 'Shell' })
      SCodeBlock({ code: '# build and run on a device\ndevecocli run --module gallery --device 127.0.0.1:5555',
        language: 'bash', showLineNumbers: false })
      DocSection({ title: 'Highlighted lines', description: 'highlightLines takes line numbers as displayed.' })
      SCodeBlock({ code: SAMPLE_TS, language: 'arkts', title: 'ClickCounter.ets', highlightLines: [3, 6] })
      DocSection({ title: 'Diff' })
      SCodeBlock({ code: SAMPLE_DIFF, language: 'diff', showLineNumbers: false })
      DocSection({
        title: 'Custom grammar',
        description: 'Ordered regex rules → token types. Register by name, or pass the grammar object directly.'
      })
      SCodeBlock({ code: SAMPLE_INI, grammar: INI_GRAMMAR, title: 'app.ini' })
      SCodeBlock({ code: INI_GRAMMAR_CODE, language: 'arkts', title: 'Register a grammar' })
      DocSection({ title: 'Extend a built-in', description: 'CodeHighlighter.extend(base, { keywords, before, after, exclude })' })
      SCodeBlock({ code: MY_ARKTS_CODE, grammar: MY_ARKTS, highlightLines: [6] })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Dialog

const DIALOG_CODE = `SDialog() {
  SDialogTrigger() {
    SButton({ text: 'Edit profile', variant: 'outline' })
  }
  SDialogContent() {
    SDialogHeader() {
      SDialogTitle({ text: 'Edit profile' })
      SDialogDescription({ text: 'Make changes to your profile here.' })
    }
    TextInput({ text: this.name })
    SDialogFooter() {
      SDialogClose() { SButton({ text: 'Cancel', variant: 'outline' }) }
      SDialogClose() { SButton({ text: 'Save changes' }) }
    }
  }
}`;

const DIALOG_CONTROLLED = `@Local open: boolean = false;

SButton({ text: 'Open' }).onClick(() => this.open = true)
SDialog({ open: this.open!! }) {
  SDialogContent() { ... }
}`;

@ComponentV2
export struct DialogDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local name: string = 'Pedro Duarte';
  @Local open: boolean = false;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Dialog',
        lead: 'A window overlaid on the primary window, rendering the content underneath inert. Closes with the ' +
          'backdrop, the back gesture / key, Esc or SDialogClose.'
      })
      DemoBlock({ code: DIALOG_CODE }) {
        SDialog() {
          SDialogTrigger() {
            SButton({ text: 'Edit profile', variant: 'outline' })
          }
          SDialogContent() {
            SDialogHeader() {
              SDialogTitle({ text: 'Edit profile' })
              SDialogDescription({ text: 'Make changes to your profile here. Click save when you are done.' })
            }
            TextInput({ text: this.name, placeholder: 'Name' })
              .onChange((v: string) => {
                this.name = v;
              })
            SDialogFooter() {
              SDialogClose() {
                SButton({ text: 'Cancel', variant: 'outline' })
              }
              SDialogClose() {
                SButton({ text: 'Save changes' })
              }
            }
          }
        }
      }
      Text(`name = ${this.name}`).fontSize(this.theme.text.xs).fontColor(this.theme.colors.mutedForeground)
      DocSection({ title: 'Controlled', description: 'Bind open state with !! like v-model:open.' })
      DemoBlock({ code: DIALOG_CONTROLLED }) {
        SButton({ text: `Open (open = ${this.open})`, variant: 'secondary' }).onClick(() => {
          this.open = true;
        })
        SDialog({ open: this.open!! }) {
          SDialogContent({ showCloseButton: false }) {
            SDialogHeader() {
              SDialogTitle({ text: 'Are you absolutely sure?' })
              SDialogDescription({ text: 'This action cannot be undone.' })
            }
            SDialogFooter() {
              SButton({ text: 'Cancel', variant: 'outline' }).onClick(() => {
                this.open = false;
              })
              SButton({ text: 'Continue', variant: 'destructive' }).onClick(() => {
                this.open = false;
              })
            }
          }
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Popover

const POPOVER_CODE = `SPopover() {
  SPopoverTrigger() {
    SButton({ text: 'Open popover', variant: 'outline' })
  }
  SPopoverContent({ side: 'bottom', alignment: 'start' }) {
    Text('Dimensions')
    TextInput({ placeholder: 'Width' })
  }
}`;

@ComponentV2
export struct PopoverDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  private sides: SparkSide[] = ['top', 'right', 'bottom', 'left'];

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Popover',
        lead: 'Displays rich content in a portal, anchored to its trigger. Flips and shifts to stay on screen.'
      })
      DemoBlock({ code: POPOVER_CODE }) {
        SPopover() {
          SPopoverTrigger() {
            SButton({ text: 'Open popover', variant: 'outline', iconRight: 'chevron-down' })
          }
          SPopoverContent({ alignment: 'start' }) {
            Column({ space: 8 }) {
              Text('Dimensions').fontWeight(this.theme.text.weightMedium).fontColor(this.theme.colors.popoverForeground)
              Text('Set the dimensions for the layer.').fontSize(this.theme.text.sm)
                .fontColor(this.theme.colors.mutedForeground)
              TextInput({ placeholder: 'Width' })
              TextInput({ placeholder: 'Height' })
            }
            .alignItems(HorizontalAlign.Start)
          }
        }
      }
      DocSection({ title: 'Side', description: 'side: top | right | bottom | left' })
      DemoBlock({ code: `SPopoverContent({ side: 'top' }) { ... }` }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: space8 }) {
          ForEach(this.sides, (s: SparkSide) => {
            SPopover() {
              SPopoverTrigger() {
                SButton({ text: s, variant: 'outline' })
              }
              SPopoverContent({ side: s, panelWidth: 200 }) {
                Text(`Opened on the ${s}`).fontSize(this.theme.text.sm).fontColor(this.theme.colors.popoverForeground)
              }
            }
          }, (s: SparkSide) => s)
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Sheet

const SHEET_CODE = `SSheet() {
  SSheetTrigger() { SButton({ text: 'Open', variant: 'outline' }) }
  SSheetContent({ side: 'right' }) {
    SSheetHeader() {
      SSheetTitle({ text: 'Edit profile' })
      SSheetDescription({ text: 'Make changes to your profile here.' })
    }
    TextInput({ placeholder: 'Name' })
    SSheetFooter() {
      SSheetClose() { SButton({ text: 'Save changes' }) }
    }
  }
}`;

@ComponentV2
export struct SheetDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  private sides: SheetSide[] = ['top', 'right', 'bottom', 'left'];

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Sheet',
        lead: 'Extends the Dialog to display content that complements the main content of the screen.'
      })
      DemoBlock({ code: SHEET_CODE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: space8 }) {
          ForEach(this.sides, (s: SheetSide) => {
            SSheet() {
              SSheetTrigger() {
                SButton({ text: s, variant: 'outline' })
              }
              SSheetContent({ side: s }) {
                SSheetHeader() {
                  SSheetTitle({ text: 'Edit profile' })
                  SSheetDescription({ text: `This sheet slides in from the ${s}.` })
                }
                TextInput({ placeholder: 'Name' })
                TextInput({ placeholder: 'Username' })
                SSheetFooter() {
                  SSheetClose() {
                    SButton({ text: 'Save changes' })
                  }
                }
              }
            }
          }, (s: SheetSide) => s)
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Card

const CARD_CODE = `SCard() {
  SCardHeader() {
    SCardTitle({ text: 'Login to your account' })
    SCardDescription({ text: 'Enter your email below to login.' })
  }
  SCardContent() {
    TextInput({ placeholder: 'm@example.com' })
    TextInput({ placeholder: 'Password' }).type(InputType.Password)
  }
  SCardFooter() {
    SButton({ text: 'Login' })
    SButton({ text: 'Login with Google', variant: 'outline' })
  }
}`;

const CARD_VARIANTS = `SCard({ variant: 'outline' }) { ... }    // border only
SCard({ variant: 'elevated' }) { ... }   // shadow-md, no border
SCard({ variant: 'filled' }) { ... }     // bg-muted
SCard({ variant: 'ghost' }) { ... }      // no surface
SCard({ sizing: 'sm' }) { ... }          // compact 16vp padding`;

const CARD_INTERACTIVE = `Stack() {
  SCard({ interactive: true, image: $r('app.media.startIcon'), imageHeight: 140 }) {
    SCardHeader() {
      SCardTitle({ text: 'Design systems' })
      SCardDescription({ text: 'Tap the whole card.' })
    }
  }
}.onClick(() => this.opened++)`;

@ComponentV2
export struct CardDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local opened: number = 0;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Card',
        lead: 'Displays a card with header, content, and footer. Padding tightens automatically when the card is narrow.'
      })
      DemoBlock({ code: CARD_CODE }) {
        Column() {
          SCard() {
            SCardHeader() {
              SCardTitle({ text: 'Login to your account' })
              SCardDescription({ text: 'Enter your email below to login to your account.' })
            }
            SCardAction() {
              SButton({ text: 'Sign Up', variant: 'link', sizing: 'sm' })
            }
            SCardContent() {
              Text('Email').fontSize(this.theme.text.sm).fontWeight(this.theme.text.weightMedium)
                .fontColor(this.theme.colors.foreground)
              TextInput({ placeholder: 'm@example.com' })
              Text('Password').fontSize(this.theme.text.sm).fontWeight(this.theme.text.weightMedium)
                .fontColor(this.theme.colors.foreground)
              TextInput({ placeholder: 'Password' }).type(InputType.Password)
            }
            SCardFooter() {
              SButton({ text: 'Login' })
              SButton({ text: 'Login with Google', variant: 'outline' })
            }
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 380 })
      }
      DocSection({ title: 'Variants', description: "variant: default | outline | elevated | filled | ghost; sizing: 'sm'." })
      DemoBlock({ code: CARD_VARIANTS }) {
        Column({ space: 16 }) {
          SCard({ variant: 'outline', sizing: 'sm' }) {
            SCardHeader() {
              SCardTitle({ text: 'Outline' })
              SCardDescription({ text: 'Border only, no shadow.' })
            }
          }
          SCard({ variant: 'elevated', sizing: 'sm' }) {
            SCardHeader() {
              SCardTitle({ text: 'Elevated' })
              SCardDescription({ text: 'shadow-md instead of a border.' })
            }
          }
          SCard({ variant: 'filled', sizing: 'sm' }) {
            SCardHeader() {
              SCardTitle({ text: 'Filled' })
              SCardDescription({ text: 'A muted surface.' })
            }
          }
          SCard({ variant: 'ghost', sizing: 'sm' }) {
            SCardHeader() {
              SCardTitle({ text: 'Ghost' })
              SCardDescription({ text: 'No surface — keeps card spacing only.' })
            }
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 380 })
      }
      DocSection({
        title: 'Interactive & media',
        description: 'interactive adds hover / pressed feedback; image puts a full-bleed header on top.'
      })
      DemoBlock({ code: CARD_INTERACTIVE }) {
        Column({ space: 12 }) {
          Stack() {
            SCard({ interactive: true, image: $r('app.media.startIcon'), imageHeight: 140 }) {
              SCardHeader() {
                SCardTitle({ text: 'Design systems' })
                SCardDescription({ text: 'Tap anywhere on the card.' })
              }
              SCardFooter() {
                SBadge({ text: 'Guide', variant: 'secondary' })
                SBadge({ text: '12 min', variant: 'outline' })
              }
            }
          }
          .onClick(() => {
            this.opened++;
          })
          Stack() {
            SCard({ variant: 'outline', interactive: true, sizing: 'sm' }) {
              SCardHeader() {
                SCardTitle({ text: 'Outline + interactive' })
                SCardDescription({ text: 'Hover (pointer) and press feedback.' })
              }
            }
          }
          .onClick(() => {
            this.opened++;
          })
          Text(`opened: ${this.opened}`)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 380 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
