import { LengthMetrics } from '@kit.ArkUI';
import {
  SAvatar, SButton, SCombobox, SCommand, SCommandDialog, SCommandEmpty, SCommandGroup, SCommandInput, SCommandItem,
  SCommandList, SCommandSeparator, SContextMenu, SContextMenuCheckboxItem, SContextMenuContent, SContextMenuItem,
  SContextMenuLabel, SContextMenuRadioGroup, SContextMenuRadioItem, SContextMenuSeparator, SContextMenuTrigger,
  SDrawer, SDrawerClose, SDrawerContent, SDrawerDescription, SDrawerFooter, SDrawerHeader, SDrawerTitle,
  SDrawerTrigger, SHoverCard, SHoverCardContent, SHoverCardTrigger, SIcon, SMenubar, SMenubarCheckboxItem,
  SMenubarContent, SMenubarItem, SMenubarMenu, SMenubarRadioGroup, SMenubarRadioItem, SMenubarSeparator,
  SMenubarTrigger, SparkCommandEntryData, SparkSelectOption, SparkTheme, SparkUI
} from '@sparkui/core';
import { DemoBlock, DemoCaption, DocHeader, DocSection } from '../shell/DocKit';

const space8: FlexSpaceOptions = { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) };

// ------------------------------------------------------------------------------------------------ HoverCard

const HOVER_CARD_CODE = `SHoverCard() {
  SHoverCardTrigger() { SButton({ text: '@nextjs', variant: 'link' }) }
  SHoverCardContent() {
    Row({ space: 16 }) {
      SAvatar({ fallback: 'VC' })
      Column({ space: 4 }) {
        Text('@nextjs')
        Text('The React Framework – created and maintained by @vercel.')
        Text('Joined December 2021')
      }
    }
  }
}`;

@ComponentV2
export struct HoverCardDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local open: boolean = false;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Hover Card',
        lead: 'For sighted users to preview content available behind a link. Opens after hovering 700 ms ' +
          '(mouse / touchpad) and stays open while the pointer is over the card; on touch, a tap toggles it.'
      })
      DemoBlock({ code: HOVER_CARD_CODE }) {
        SHoverCard({ open: this.open!! }) {
          SHoverCardTrigger() {
            SButton({ text: '@nextjs', variant: 'link' })
          }
          SHoverCardContent() {
            Row({ space: 16 }) {
              SAvatar({ fallback: 'VC' })
              Column({ space: 4 }) {
                Text('@nextjs')
                  .fontSize(this.theme.text.sm)
                  .fontWeight(this.theme.text.weightSemibold)
                  .fontColor(this.theme.colors.popoverForeground)
                Text('The React Framework – created and maintained by @vercel.')
                  .fontSize(this.theme.text.sm)
                  .fontColor(this.theme.colors.popoverForeground)
                Row({ space: 6 }) {
                  SIcon({ name: 'calendar', sizing: 14, color: this.theme.colors.mutedForeground })
                  Text('Joined December 2021')
                    .fontSize(this.theme.text.xs)
                    .fontColor(this.theme.colors.mutedForeground)
                }
                .margin({ top: 4 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }
        }
      }
      Text(`open = ${this.open}`).fontSize(this.theme.text.xs).fontColor(this.theme.colors.mutedForeground)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ ContextMenu

const CONTEXT_MENU_CODE = `SContextMenu() {
  SContextMenuTrigger() { /* any area */ }
  SContextMenuContent() {
    SContextMenuItem({ text: 'Back', shortcut: '⌘[', onSelect: () => ... })
    SContextMenuItem({ text: 'Forward', shortcut: '⌘]', disabled: true })
    SContextMenuItem({ text: 'Reload', shortcut: '⌘R', onSelect: () => ... })
    SContextMenuSeparator()
    SContextMenuCheckboxItem({ text: 'Show Bookmarks', checked: this.bookmarks!! })
    SContextMenuCheckboxItem({ text: 'Show Full URLs', checked: this.urls!! })
    SContextMenuSeparator()
    SContextMenuLabel({ text: 'People', inset: true })
    SContextMenuRadioGroup({ value: this.person!! }) {
      SContextMenuRadioItem({ value: 'pedro', text: 'Pedro Duarte' })
      SContextMenuRadioItem({ value: 'colm', text: 'Colm Tuite' })
    }
  }
}`;

@ComponentV2
export struct ContextMenuDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local last: string = '—';
  @Local bookmarks: boolean = true;
  @Local urls: boolean = false;
  @Local person: string = 'pedro';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Context Menu',
        lead: 'A menu of actions for an area, opened with a right click at the pointer (mouse / touchpad) or a ' +
          'long press at the finger (touch). Becomes a bottom sheet on compact touch screens.'
      })
      DemoBlock({ code: CONTEXT_MENU_CODE }) {
        SContextMenu() {
          SContextMenuTrigger() {
            Column() {
              Text(SparkUI.layout.env.modality === 'pointer' ? 'Right click here' : 'Long-press here')
                .fontSize(this.theme.text.sm)
                .fontColor(this.theme.colors.foreground)
            }
            .width(300)
            .height(150)
            .justifyContent(FlexAlign.Center)
            .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusMd, style: BorderStyle.Dashed })
          }
          SContextMenuContent() {
            SContextMenuItem({ text: 'Back', shortcut: '⌘[', inset: true, onSelect: () => {
              this.last = 'Back';
            } })
            SContextMenuItem({ text: 'Forward', shortcut: '⌘]', inset: true, disabled: true })
            SContextMenuItem({
              text: 'Reload', shortcut: '⌘R', inset: true, onSelect: () => {
                this.last = 'Reload';
              }
            })
            SContextMenuItem({ text: 'Delete', icon: 'trash', variant: 'destructive', onSelect: () => {
              this.last = 'Delete';
            } })
            SContextMenuSeparator()
            SContextMenuCheckboxItem({ text: 'Show Bookmarks', checked: this.bookmarks!! })
            SContextMenuCheckboxItem({ text: 'Show Full URLs', checked: this.urls!! })
            SContextMenuSeparator()
            SContextMenuLabel({ text: 'People', inset: true })
            SContextMenuRadioGroup({ value: this.person!! }) {
              SContextMenuRadioItem({ value: 'pedro', text: 'Pedro Duarte' })
              SContextMenuRadioItem({ value: 'colm', text: 'Colm Tuite' })
            }
          }
        }
      }
      Text(`last = ${this.last} · bookmarks = ${this.bookmarks} · urls = ${this.urls} · person = ${this.person}`)
        .fontSize(this.theme.text.xs)
        .fontColor(this.theme.colors.mutedForeground)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Command

const COMMAND_CODE = `SCommand() {
  SCommandInput({ placeholder: 'Type a command or search…' })
  SCommandList() {
    SCommandEmpty({ text: 'No results found.' })
    SCommandGroup({ heading: 'Suggestions' }) {
      SCommandItem({ value: 'calendar', text: 'Calendar', icon: 'calendar' })
      SCommandItem({ value: 'emoji', text: 'Search Emoji', icon: 'sparkles', keywords: ['smile', 'face'] })
      SCommandItem({ value: 'calculator', text: 'Calculator', icon: 'zap', disabled: true })
    }
    SCommandSeparator()
    SCommandGroup({ heading: 'Settings' }) {
      SCommandItem({ value: 'profile', text: 'Profile', icon: 'user', shortcut: '⌘P' })
      SCommandItem({ value: 'settings', text: 'Settings', icon: 'settings', shortcut: '⌘S',
        onSelect: (v: string) => ... })
    }
  }
}

// palette in a dialog
SCommandDialog({ open: this.palette!! }) { SCommandInput() SCommandList() { ... } }`;

const COMMAND_GROUPS: string[] = ['Files', 'Folders', 'Commands', 'Settings'];
const COMMAND_ICONS: string[] = ['file', 'folder', 'terminal', 'settings'];
const COMMAND_WORDS: string[] = ['alpha', 'bravo', 'charlie', 'delta', 'echo', 'foxtrot', 'golf', 'hotel', 'india',
  'juliet'];

/** 2 000 generated commands in four groups of 500 ("Files" → "alpha report 1", …); every 50th is disabled. */
function manyCommands(count: number): SparkCommandEntryData[] {
  const out: SparkCommandEntryData[] = [];
  const per = Math.ceil(count / COMMAND_GROUPS.length);
  for (let i = 0; i < count; i++) {
    const g = Math.floor(i / per);
    const label = `${COMMAND_WORDS[i % 10]} ${COMMAND_GROUPS[g].toLowerCase().slice(0, -1)} ${Math.floor(i / 10) + 1}`;
    out.push(new SparkCommandEntryData({
      value: `cmd-${i}`,
      label: label.charAt(0).toUpperCase() + label.slice(1),
      group: COMMAND_GROUPS[g],
      icon: COMMAND_ICONS[g],
      shortcut: i % 100 === 0 ? `⌘${g + 1}` : undefined,
      keywords: [COMMAND_GROUPS[g]],
      disabled: i % 50 === 49
    }));
  }
  return out;
}

const MANY_COMMANDS: SparkCommandEntryData[] = manyCommands(2000);

const COMMAND_DATA_CODE = `// 2 000 items: the data mode filters with the same cmdk scoring, keeps document order,
// and renders a List + Repeat.virtualScroll() — non-matching items are never built,
// and of the matches only the rows in view are. ↑ / ↓ + Enter work from the search field.
const COMMANDS: SparkCommandEntryData[] = [
  new SparkCommandEntryData({ value: 'cmd-0', label: 'Alpha file 1', group: 'Files', icon: 'file',
    shortcut: '⌘1', keywords: ['Files'], onSelect: (v: string) => ... }),
  ...
];

SCommand({
  items: COMMANDS,
  placeholder: 'Search 2 000 commands…',
  emptyText: 'No command found.',
  maxListHeight: 300,
  onItemSelect: (v: string) => { this.picked = v; }
})

// also as a palette
SCommandDialog({ open: this.palette!!, items: COMMANDS, onItemSelect: (v: string) => ... })`;

@ComponentV2
export struct CommandDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local selected: string = '—';
  @Local query: string = '';
  @Local palette: boolean = false;
  @Local bigPalette: boolean = false;
  @Local bigQuery: string = '';
  @Local bigPicked: string = '';

  @Builder
  items() {
    SCommandEmpty({ text: 'No results found.' })
    SCommandGroup({ heading: 'Suggestions' }) {
      SCommandItem({
        value: 'calendar', text: 'Calendar', icon: 'calendar', keywords: ['date', 'schedule'],
        onSelect: (v: string) => {
          this.selected = v;
        }
      })
      SCommandItem({
        value: 'emoji', text: 'Search Emoji', icon: 'sparkles', keywords: ['smile', 'face'],
        onSelect: (v: string) => {
          this.selected = v;
        }
      })
      SCommandItem({ value: 'calculator', text: 'Calculator', icon: 'zap', disabled: true })
    }
    SCommandSeparator()
    SCommandGroup({ heading: 'Settings' }) {
      SCommandItem({
        value: 'profile', text: 'Profile', icon: 'user', shortcut: '⌘P',
        onSelect: (v: string) => {
          this.selected = v;
        }
      })
      SCommandItem({
        value: 'billing', text: 'Billing', icon: 'credit-card', shortcut: '⌘B',
        onSelect: (v: string) => {
          this.selected = v;
        }
      })
      SCommandItem({
        value: 'settings', text: 'Settings', icon: 'settings', shortcut: '⌘S',
        onSelect: (v: string) => {
          this.selected = v;
        }
      })
    }
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Command',
        lead: 'Fast, composable command menu. Type to filter (prefix, substring or fuzzy subsequence, plus ' +
          'keywords); ↑ / ↓ move the highlight and Enter selects it.'
      })
      DemoBlock({ code: COMMAND_CODE }) {
        Column() {
          SCommand({
            onQueryChange: (q: string) => {
              this.query = q;
            }
          }) {
            SCommandInput({ placeholder: 'Type a command or search…' })
            SCommandList() {
              this.items()
            }
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 450 })
        .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg })
        .shadow(this.theme.shadows.md.toOptions())
      }
      Text(`query = "${this.query}" · selected = ${this.selected}`)
        .fontSize(this.theme.text.xs)
        .fontColor(this.theme.colors.mutedForeground)
      DocSection({ title: 'Dialog', description: 'SCommandDialog shows the palette in a centred dialog and ' +
        'closes after a selection.' })
      DemoBlock({ code: `SButton({ text: 'Open command palette' }).onClick(() => { this.palette = true; })
SCommandDialog({ open: this.palette!! }) {
  SCommandInput({ placeholder: 'Type a command or search…', autoFocus: true })
  SCommandList() { ... }
}` }) {
        Column() {
          SButton({ text: 'Open command palette', variant: 'outline', icon: 'command' }).onClick(() => {
            this.palette = true;
          })
          SCommandDialog({ open: this.palette!! }) {
            SCommandInput({ placeholder: 'Type a command or search…', autoFocus: SparkUI.layout.env.modality === 'pointer' })
            SCommandList() {
              this.items()
            }
          }
        }
      }
      Text(`palette open = ${this.palette}`)
        .fontSize(this.theme.text.xs)
        .fontColor(this.theme.colors.mutedForeground)
      DocSection({
        title: 'Long lists (data mode)',
        description: 'Pass items instead of slot content: the results are virtualized, so items that do not ' +
          'match are never built and only the matches in view are. Try "echo 42", "set 19" or "dlt".'
      })
      DemoBlock({ code: COMMAND_DATA_CODE }) {
        Column({ space: 12 }) {
          Column() {
            SCommand({
              items: MANY_COMMANDS,
              placeholder: 'Search 2 000 commands…',
              emptyText: 'No command found.',
              onQueryChange: (q: string) => {
                this.bigQuery = q;
              },
              onItemSelect: (v: string) => {
                this.bigPicked = v;
              }
            })
          }
          .width('100%')
          .constraintSize({ maxWidth: 450 })
          .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg })
          .shadow(this.theme.shadows.md.toOptions())

          SButton({ text: 'Open 2 000-item palette', variant: 'outline', icon: 'command' }).onClick(() => {
            this.bigPalette = true;
          })
          SCommandDialog({
            open: this.bigPalette!!,
            items: MANY_COMMANDS,
            placeholder: 'Search 2 000 commands…',
            emptyText: 'No command found.',
            autoFocus: SparkUI.layout.env.modality === 'pointer',
            onItemSelect: (v: string) => {
              this.bigPicked = v;
            }
          })
        }
        .alignItems(HorizontalAlign.Start)
      }
      DemoCaption({
        text: `${MANY_COMMANDS.length} items · query = "${this.bigQuery}" · selected = ${this.bigPicked || '(none)'}`
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Combobox

const FRAMEWORKS: SparkSelectOption[] = [
  new SparkSelectOption('next.js', 'Next.js'),
  new SparkSelectOption('sveltekit', 'SvelteKit'),
  new SparkSelectOption('nuxt.js', 'Nuxt.js'),
  new SparkSelectOption('remix', 'Remix'),
  new SparkSelectOption('astro', 'Astro')
];

const LANGUAGES: SparkSelectOption[] = [
  new SparkSelectOption('ts', 'TypeScript', false, 'Web'),
  new SparkSelectOption('js', 'JavaScript'),
  new SparkSelectOption('arkts', 'ArkTS', false, 'Native'),
  new SparkSelectOption('swift', 'Swift'),
  new SparkSelectOption('kotlin', 'Kotlin'),
  new SparkSelectOption('cobol', 'COBOL', true)
];

const COMBOBOX_CODE = `const FRAMEWORKS: SparkSelectOption[] = [
  new SparkSelectOption('next.js', 'Next.js'),
  new SparkSelectOption('sveltekit', 'SvelteKit'),
  ...
];

SCombobox({
  value: this.framework!!,
  options: FRAMEWORKS,
  placeholder: 'Select framework…',
  searchPlaceholder: 'Search framework…',
  emptyText: 'No framework found.'
})`;

const CITY_PARTS: string[] = ['North', 'South', 'East', 'West', 'Upper', 'Lower', 'New', 'Old', 'Port', 'Lake'];
const CITY_ROOTS: string[] = ['haven', 'field', 'bridge', 'ford', 'wood', 'stone', 'brook', 'ridge', 'vale', 'mouth'];

/** 1 000 generated place names ("North haven 1", …) to search through. */
function manyPlaces(count: number): SparkSelectOption[] {
  const out: SparkSelectOption[] = [];
  for (let i = 0; i < count; i++) {
    const name = `${CITY_PARTS[i % 10]} ${CITY_ROOTS[Math.floor(i / 10) % 10]} ${Math.floor(i / 100) + 1}`;
    out.push(new SparkSelectOption(`place-${i}`, name));
  }
  return out;
}

const MANY_PLACES: SparkSelectOption[] = manyPlaces(1000);

const COMBOBOX_LONG_CODE = `// 1 000 options: filtering keeps only the matches, and only the visible
// matches are built (List + Repeat.virtualScroll()). ↑ / ↓ + Enter work from the search field.
SCombobox({
  value: this.place!!,
  options: MANY_PLACES,
  placeholder: 'Select place…',
  searchPlaceholder: 'Search 1 000 places…',
  triggerWidth: 260
})`;

@ComponentV2
export struct ComboboxDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local framework: string = '';
  @Local language: string = 'arkts';
  @Local place: string = '';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Combobox',
        lead: 'Autocomplete input and command palette with a list of suggestions. Anchored below the trigger ' +
          '(at least as wide as it) on pointer / wide screens; a bottom sheet on compact touch screens.'
      })
      DemoBlock({ code: COMBOBOX_CODE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: space8 }) {
          SCombobox({
            value: this.framework!!,
            options: FRAMEWORKS,
            placeholder: 'Select framework…',
            searchPlaceholder: 'Search framework…',
            emptyText: 'No framework found.'
          })
          SCombobox({
            value: this.language!!,
            options: LANGUAGES,
            placeholder: 'Select language…',
            searchPlaceholder: 'Search language…',
            emptyText: 'No language found.',
            triggerWidth: 240
          })
        }
      }
      Text(`framework = ${this.framework || '(none)'} · language = ${this.language || '(none)'}`)
        .fontSize(this.theme.text.xs)
        .fontColor(this.theme.colors.mutedForeground)
      DocSection({
        title: 'Long lists',
        description: 'Results are virtualized: options that do not match the query are never built, and of the ' +
          'matches only the rows in view are. Try "north 7" or "brk".'
      })
      DemoBlock({ code: COMBOBOX_LONG_CODE }) {
        SCombobox({
          value: this.place!!,
          options: MANY_PLACES,
          placeholder: 'Select place…',
          searchPlaceholder: 'Search 1 000 places…',
          emptyText: 'No place found.',
          triggerWidth: 260
        })
      }
      DemoCaption({ text: `${MANY_PLACES.length} options · place = ${this.place || '(none)'}` })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Drawer

const DRAWER_CODE = `SDrawer({ open: this.open!! }) {
  SDrawerTrigger() { SButton({ text: 'Open Drawer', variant: 'outline' }) }
  SDrawerContent() {
    SDrawerHeader() {
      SDrawerTitle({ text: 'Move Goal' })
      SDrawerDescription({ text: 'Set your daily activity goal.' })
    }
    ...
    SDrawerFooter() {
      SButton({ text: 'Submit' })
      SDrawerClose() { SButton({ text: 'Cancel', variant: 'outline' }) }
    }
  }
}`;

@ComponentV2
export struct DrawerDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local open: boolean = false;
  @Local goal: number = 350;
  @Local saved: number = 350;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Drawer',
        lead: 'A drawer that slides up from the bottom. Drag it down to dismiss: release past 30% of its ' +
          'height or fling it down to close; otherwise it springs back.'
      })
      DemoBlock({ code: DRAWER_CODE }) {
        SDrawer({ open: this.open!! }) {
          SDrawerTrigger() {
            SButton({ text: 'Open Drawer', variant: 'outline' })
          }
          SDrawerContent() {
            SDrawerHeader() {
              SDrawerTitle({ text: 'Move Goal' })
              SDrawerDescription({ text: 'Set your daily activity goal.' })
            }
            Row({ space: 16 }) {
              SButton({ variant: 'outline', sizing: 'icon', icon: 'minus', label: 'Decrease', disabled: this.goal <= 200 })
                .onClick(() => {
                  this.goal = Math.max(200, this.goal - 10);
                })
              Column() {
                Text(`${this.goal}`)
                  .fontSize(56)
                  .fontWeight(this.theme.text.weightBold)
                  .fontColor(this.theme.colors.foreground)
                Text('CALORIES/DAY')
                  .fontSize(this.theme.text.xs)
                  .fontColor(this.theme.colors.mutedForeground)
              }
              .layoutWeight(1)
              SButton({ variant: 'outline', sizing: 'icon', icon: 'plus', label: 'Increase', disabled: this.goal >= 400 })
                .onClick(() => {
                  this.goal = Math.min(400, this.goal + 10);
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            SDrawerFooter() {
              SButton({ text: 'Submit' }).width('100%').onClick(() => {
                this.saved = this.goal;
                this.open = false;
              })
              SDrawerClose() {
                SButton({ text: 'Cancel', variant: 'outline' }).width('100%')
              }
            }
          }
        }
      }
      Text(`open = ${this.open} · saved goal = ${this.saved}`)
        .fontSize(this.theme.text.xs)
        .fontColor(this.theme.colors.mutedForeground)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Menubar

const MENUBAR_CODE = `SMenubar() {
  SMenubarMenu() {
    SMenubarTrigger({ text: 'File' })
    SMenubarContent() {
      SMenubarItem({ text: 'New Tab', shortcut: '⌘T', onSelect: () => ... })
      SMenubarItem({ text: 'New Window', shortcut: '⌘N' })
      SMenubarSeparator()
      SMenubarItem({ text: 'Print…', shortcut: '⌘P' })
    }
  }
  SMenubarMenu() {
    SMenubarTrigger({ text: 'View' })
    SMenubarContent() {
      SMenubarCheckboxItem({ text: 'Always Show Bookmarks Bar', checked: this.bookmarks!! })
    }
  }
  SMenubarMenu() {
    SMenubarTrigger({ text: 'Profiles' })
    SMenubarContent() {
      SMenubarRadioGroup({ value: this.profile!! }) {
        SMenubarRadioItem({ value: 'andy', text: 'Andy' })
        SMenubarRadioItem({ value: 'benoit', text: 'Benoit' })
      }
    }
  }
}`;

@ComponentV2
export struct MenubarDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local last: string = '—';
  @Local bookmarks: boolean = false;
  @Local fullUrls: boolean = true;
  @Local profile: string = 'benoit';
  @Local narrow: boolean = false;

  @Builder
  bar() {
    SMenubar() {
      SMenubarMenu() {
        SMenubarTrigger({ text: 'File' })
        SMenubarContent() {
          SMenubarItem({ text: 'New Tab', shortcut: '⌘T', onSelect: () => {
            this.last = 'New Tab';
          } })
          SMenubarItem({
            text: 'New Window', shortcut: '⌘N', onSelect: () => {
              this.last = 'New Window';
            }
          })
          SMenubarItem({ text: 'New Incognito Window', disabled: true })
          SMenubarSeparator()
          SMenubarItem({ text: 'Print…', shortcut: '⌘P', onSelect: () => {
            this.last = 'Print';
          } })
        }
      }
      SMenubarMenu() {
        SMenubarTrigger({ text: 'Edit' })
        SMenubarContent() {
          SMenubarItem({ text: 'Undo', shortcut: '⌘Z', onSelect: () => {
            this.last = 'Undo';
          } })
          SMenubarItem({ text: 'Redo', shortcut: '⇧⌘Z', onSelect: () => {
            this.last = 'Redo';
          } })
          SMenubarSeparator()
          SMenubarItem({ text: 'Cut', onSelect: () => {
            this.last = 'Cut';
          } })
          SMenubarItem({ text: 'Copy', onSelect: () => {
            this.last = 'Copy';
          } })
          SMenubarItem({ text: 'Paste', onSelect: () => {
            this.last = 'Paste';
          } })
        }
      }
      SMenubarMenu() {
        SMenubarTrigger({ text: 'View' })
        SMenubarContent({ panelWidth: 240 }) {
          SMenubarCheckboxItem({ text: 'Always Show Bookmarks Bar', checked: this.bookmarks!! })
          SMenubarCheckboxItem({ text: 'Always Show Full URLs', checked: this.fullUrls!! })
          SMenubarSeparator()
          SMenubarItem({ text: 'Reload', shortcut: '⌘R', inset: true, onSelect: () => {
            this.last = 'Reload';
          } })
        }
      }
      SMenubarMenu() {
        SMenubarTrigger({ text: 'Profiles' })
        SMenubarContent() {
          SMenubarRadioGroup({ value: this.profile!! }) {
            SMenubarRadioItem({ value: 'andy', text: 'Andy' })
            SMenubarRadioItem({ value: 'benoit', text: 'Benoit' })
            SMenubarRadioItem({ value: 'luis', text: 'Luis' })
          }
          SMenubarSeparator()
          SMenubarItem({ text: 'Add Profile…', inset: true, onSelect: () => {
            this.last = 'Add Profile';
          } })
        }
      }
    }
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Menubar',
        lead: 'A visually persistent menu common in desktop applications. While a menu is open, hovering ' +
          'another trigger switches to it and ← / → move between menus. Menus that don\'t fit collapse into a ' +
          'trailing "More" menu.'
      })
      DemoBlock({ code: MENUBAR_CODE, centered: false }) {
        this.bar()
      }
      Text(`last = ${this.last} · bookmarks = ${this.bookmarks} · fullUrls = ${this.fullUrls} · profile = ${this.profile}`)
        .fontSize(this.theme.text.xs)
        .fontColor(this.theme.colors.mutedForeground)
      DocSection({
        title: 'Responsive',
        description: 'The bar measures its own width. Narrow it and the trailing menus move into "More", listed ' +
          'under their names.'
      })
      DemoBlock({ code: `Column() { SMenubar() { ... } }.width(this.narrow ? 200 : '100%')`, centered: false }) {
        Column({ space: 12 }) {
          SButton({ text: this.narrow ? 'Widen' : 'Narrow to 200vp', variant: 'outline', sizing: 'sm' })
            .onClick(() => {
              this.narrow = !this.narrow;
            })
          Column() {
            this.bar()
          }
          .width(this.narrow ? 200 : '100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
