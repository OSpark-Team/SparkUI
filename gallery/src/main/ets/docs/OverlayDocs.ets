import { LengthMetrics } from '@kit.ArkUI';
import {
  SAlertDialog, SAlertDialogAction, SAlertDialogCancel, SAlertDialogContent, SAlertDialogTrigger, SButton,
  SDialogDescription, SDialogFooter, SDialogHeader, SDialogTitle, SDropdownMenu, SDropdownMenuCheckboxItem,
  SDropdownMenuContent, SDropdownMenuItem, SDropdownMenuLabel, SDropdownMenuRadioGroup, SDropdownMenuRadioItem,
  SDropdownMenuSeparator, SDropdownMenuTrigger, SSelect, SSelectContent, SSelectItem, SSelectLabel, SSelectTrigger,
  SSelectSeparator, SparkSelectOption, SparkTheme, SparkToast, SparkToastAction, SparkUI, STooltip, STooltipContent,
  STooltipTrigger, SparkSide
} from '@ospark/sparkui';
import { DemoBlock, DemoCaption, DocHeader, DocSection } from '../shell/DocKit';

const space8: FlexSpaceOptions = { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) };

// ------------------------------------------------------------------------------------------------ AlertDialog

const ALERT_CODE = `SAlertDialog() {
  SAlertDialogTrigger() { SButton({ text: 'Delete account', variant: 'destructive' }) }
  SAlertDialogContent() {
    SDialogHeader() {
      SDialogTitle({ text: 'Are you absolutely sure?' })
      SDialogDescription({ text: 'This action cannot be undone.' })
    }
    SDialogFooter() {
      SAlertDialogCancel()
      SAlertDialogAction({ text: 'Continue', onAction: () => this.deleteAccount() })
    }
  }
}`;

@ComponentV2
export struct AlertDialogDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local result: string = '—';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Alert Dialog',
        lead: 'A modal dialog that interrupts the user with important content and expects a response. ' +
          'Becomes a bottom drawer on compact touch screens.'
      })
      DemoBlock({ code: ALERT_CODE }) {
        SAlertDialog() {
          SAlertDialogTrigger() {
            SButton({ text: 'Delete account', variant: 'destructive' })
          }
          SAlertDialogContent() {
            SDialogHeader() {
              SDialogTitle({ text: 'Are you absolutely sure?' })
              SDialogDescription({
                text: 'This action cannot be undone. This will permanently delete your account and remove your ' +
                  'data from our servers.'
              })
            }
            SDialogFooter() {
              SAlertDialogCancel({ onCancel: () => {
                this.result = 'cancelled';
              } })
              SAlertDialogAction({ text: 'Continue', variant: 'destructive', onAction: () => {
                this.result = 'confirmed';
              } })
            }
          }
        }
      }
      Text(`result: ${this.result}`).fontSize(this.theme.text.xs).fontColor(this.theme.colors.mutedForeground)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Tooltip

const TOOLTIP_CODE = `STooltip() {
  STooltipTrigger() { SButton({ variant: 'outline', text: 'Hover' }) }
  STooltipContent({ text: 'Add to library' })
}`;

@ComponentV2
export struct TooltipDoc {
  private sides: SparkSide[] = ['top', 'right', 'bottom', 'left'];

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Tooltip',
        lead: 'Shows information on hover (mouse / touchpad) or on long-press (touch). Flips to stay on screen.'
      })
      DemoBlock({ code: TOOLTIP_CODE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: space8 }) {
          ForEach(this.sides, (s: SparkSide) => {
            STooltip() {
              STooltipTrigger() {
                SButton({ variant: 'outline', text: s })
              }
              STooltipContent({ text: `Tooltip on ${s}`, side: s })
            }
          }, (s: SparkSide) => s)
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ DropdownMenu

const MENU_CODE = `SDropdownMenu() {
  SDropdownMenuTrigger() { SButton({ text: 'Open', variant: 'outline' }) }
  SDropdownMenuContent() {
    SDropdownMenuLabel({ text: 'My Account' })
    SDropdownMenuSeparator()
    SDropdownMenuItem({ text: 'Profile', icon: 'user', shortcut: '⇧⌘P', onSelect: () => ... })
    SDropdownMenuItem({ text: 'Settings', icon: 'settings', shortcut: '⌘S' })
    SDropdownMenuSeparator()
    SDropdownMenuItem({ text: 'Log out', icon: 'log-out', variant: 'destructive' })
  }
}`;

@ComponentV2
export struct DropdownMenuDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local last: string = '—';
  @Local statusBar: boolean = true;
  @Local panelPosition: string = 'bottom';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Dropdown Menu',
        lead: 'A menu of actions triggered by a button. Anchored on pointer / wide screens; a bottom sheet with ' +
          'touch-sized rows on compact touch screens — automatically.'
      })
      DemoBlock({ code: MENU_CODE }) {
        SDropdownMenu() {
          SDropdownMenuTrigger() {
            SButton({ text: 'Open menu', variant: 'outline', iconRight: 'chevron-down' })
          }
          SDropdownMenuContent() {
            SDropdownMenuLabel({ text: 'My Account' })
            SDropdownMenuSeparator()
            SDropdownMenuItem({ text: 'Profile', icon: 'user', shortcut: '⇧⌘P', onSelect: () => {
              this.last = 'Profile';
            } })
            SDropdownMenuItem({ text: 'Billing', icon: 'credit-card', shortcut: '⌘B', onSelect: () => {
              this.last = 'Billing';
            } })
            SDropdownMenuItem({ text: 'Settings', icon: 'settings', shortcut: '⌘S', onSelect: () => {
              this.last = 'Settings';
            } })
            SDropdownMenuItem({ text: 'API (disabled)', icon: 'cloud', disabled: true })
            SDropdownMenuSeparator()
            SDropdownMenuItem({ text: 'Log out', icon: 'log-out', variant: 'destructive', onSelect: () => {
              this.last = 'Log out';
            } })
          }
        }
      }
      Text(`last action: ${this.last}`).fontSize(this.theme.text.xs).fontColor(this.theme.colors.mutedForeground)
      DocSection({ title: 'Checkbox & radio items' })
      DemoBlock({ code: `SDropdownMenuCheckboxItem({ text: 'Status Bar', checked: this.statusBar!! })
SDropdownMenuRadioGroup({ value: this.panelPosition!! }) {
  SDropdownMenuRadioItem({ value: 'top', text: 'Top' })
  SDropdownMenuRadioItem({ value: 'bottom', text: 'Bottom' })
}` }) {
        SDropdownMenu() {
          SDropdownMenuTrigger() {
            SButton({ text: 'View options', variant: 'outline', icon: 'sliders-horizontal' })
          }
          SDropdownMenuContent() {
            SDropdownMenuLabel({ text: 'Appearance' })
            SDropdownMenuSeparator()
            SDropdownMenuCheckboxItem({ text: 'Status Bar', checked: this.statusBar!! })
            SDropdownMenuSeparator()
            SDropdownMenuLabel({ text: 'Panel Position' })
            SDropdownMenuRadioGroup({ value: this.panelPosition!! }) {
              SDropdownMenuRadioItem({ value: 'top', text: 'Top' })
              SDropdownMenuRadioItem({ value: 'bottom', text: 'Bottom' })
              SDropdownMenuRadioItem({ value: 'right', text: 'Right' })
            }
          }
        }
      }
      Text(`statusBar = ${this.statusBar} · position = ${this.panelPosition}`)
        .fontSize(this.theme.text.xs)
        .fontColor(this.theme.colors.mutedForeground)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Select

const FRUITS: SparkSelectOption[] = [
  new SparkSelectOption('apple', 'Apple', false, 'Fruits'),
  new SparkSelectOption('banana', 'Banana'),
  new SparkSelectOption('blueberry', 'Blueberry'),
  new SparkSelectOption('grapes', 'Grapes', true),
  new SparkSelectOption('pineapple', 'Pineapple')
];

const SELECT_CODE = `// data-driven
SSelect({ value: this.fruit!!, placeholder: 'Select a fruit', options: FRUITS })

// compound, like shadcn
SSelect({ value: this.tz!! }) {
  SSelectTrigger({ placeholder: 'Timezone' })
  SSelectContent() {
    SSelectLabel({ text: 'Asia' })
    SSelectItem({ value: 'cst', text: 'China Standard Time' })
    SSelectSeparator()
    SSelectLabel({ text: 'Europe' })
    SSelectItem({ value: 'cet', text: 'Central European Time' })
  }
}`;

/** 1 000 options in 10 groups — the data form is virtualized, so this opens as fast as five. */
function manyOptions(count: number, groupSize: number): SparkSelectOption[] {
  const out: SparkSelectOption[] = [];
  for (let i = 0; i < count; i++) {
    const n = String(i + 1).padStart(4, '0');
    out.push(new SparkSelectOption(`item-${n}`, `Item ${n}`, i % 97 === 13,
      i % groupSize === 0 ? `Items ${i + 1}–${Math.min(count, i + groupSize)}` : undefined));
  }
  return out;
}

const MANY_OPTIONS: SparkSelectOption[] = manyOptions(1000, 100);

const SELECT_LONG_CODE = `// 1 000 options: List + Repeat.virtualScroll() — only the visible rows are built,
// and the list opens scrolled to the selected option.
SSelect({ value: this.item!!, placeholder: 'Pick an item', options: MANY_OPTIONS })`;

@ComponentV2
export struct SelectDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local fruit: string = '';
  @Local tz: string = 'cst';
  @Local item: string = 'item-0500';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Select',
        lead: 'Displays a list of options to pick from. The list is at least as wide as its trigger, scrolls when ' +
          'long, and becomes a bottom sheet on compact touch screens.'
      })
      DemoBlock({ code: SELECT_CODE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: space8 }) {
          Column() {
            SSelect({ value: this.fruit!!, placeholder: 'Select a fruit', options: FRUITS })
          }
          .width(200)

          Column() {
            SSelect({ value: this.tz!! }) {
              SSelectTrigger({ placeholder: 'Timezone' })
              SSelectContent() {
                SSelectLabel({ text: 'Asia' })
                SSelectItem({ value: 'cst', text: 'China Standard Time' })
                SSelectItem({ value: 'jst', text: 'Japan Standard Time' })
                SSelectSeparator()
                SSelectLabel({ text: 'Europe' })
                SSelectItem({ value: 'cet', text: 'Central European Time' })
                SSelectItem({ value: 'gmt', text: 'Greenwich Mean Time' })
              }
            }
          }
          .width(240)
        }
      }
      Text(`fruit = ${this.fruit || '(none)'} · tz = ${this.tz}`)
        .fontSize(this.theme.text.xs)
        .fontColor(this.theme.colors.mutedForeground)
      DocSection({
        title: 'Long lists',
        description: 'The data form is virtualized: only the rows in view exist, scrolled-out rows are reused, and ' +
          'the list opens at the selected option. Every 97th item is disabled.'
      })
      DemoBlock({ code: SELECT_LONG_CODE }) {
        Column() {
          SSelect({ value: this.item!!, placeholder: 'Pick an item', options: MANY_OPTIONS })
        }
        .width(240)
      }
      DemoCaption({ text: `${MANY_OPTIONS.length} options · item = ${this.item || '(none)'}` })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Toast

const TOAST_DURATION_CODE = `SparkToast.show('Gone in 2 seconds', { duration: 2000 })
SparkToast.info('Stays for 10 seconds', undefined, 10000)
SparkToast.warning('Pinned', 'Swipe it sideways to dismiss.', 0)   // 0 = until dismissed
SparkToast.dismissAll()

// app-wide defaults
SparkToast.configure({ duration: 6000, max: 4 })`;

const TOAST_CODE = `SparkToast.show('Event has been created', {
  description: 'Sunday, December 03, 2023 at 9:00 AM',
  action: new SparkToastAction('Undo', () => this.undo())
})
SparkToast.success('Profile saved')
const id = SparkToast.loading('Uploading…')
SparkToast.update(id, 'Uploaded', { variant: 'success' })`;

@ComponentV2
export struct ToastDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local undone: number = 0;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Toast (Sonner)',
        lead: 'An opinionated toast. Bottom-right on wide windows, bottom-centre on compact ones. Swipe sideways ' +
          'to dismiss; touches outside the toasts go straight to the page.'
      })
      DemoBlock({ code: TOAST_CODE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: space8 }) {
          SButton({ text: 'Show toast', variant: 'outline' }).onClick(() => {
            SparkToast.show('Event has been created', {
              description: 'Sunday, December 03, 2023 at 9:00 AM',
              action: new SparkToastAction('Undo', () => {
                this.undone++;
              })
            });
          })
          SButton({ text: 'Success', variant: 'outline' }).onClick(() => SparkToast.success('Profile saved'))
          SButton({ text: 'Error', variant: 'outline' })
            .onClick(() => SparkToast.error('Upload failed', 'The file is larger than 10 MB.'))
          SButton({ text: 'Loading → done', variant: 'outline' }).onClick(() => {
            const id = SparkToast.loading('Uploading…');
            setTimeout(() => SparkToast.update(id, 'Uploaded', { variant: 'success' }), 1800);
          })
        }
      }
      Text(`undo pressed: ${this.undone}`).fontSize(this.theme.text.xs).fontColor(this.theme.colors.mutedForeground)

      DocSection({ title: 'Duration', description: 'Each toast auto-dismisses after its duration (default 4 s). ' +
        'Pass duration: 0 to keep it until it is swiped away or dismissed; SparkToast.configure() sets the defaults.' })
      DemoBlock({ code: TOAST_DURATION_CODE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: space8 }) {
          SButton({ text: '2 s', variant: 'outline' })
            .onClick(() => SparkToast.show('Gone in 2 seconds', { duration: 2000 }))
          SButton({ text: '10 s', variant: 'outline' })
            .onClick(() => SparkToast.info('Stays for 10 seconds', undefined, 10000))
          SButton({ text: 'Until dismissed', variant: 'outline' })
            .onClick(() => SparkToast.warning('Pinned', 'Swipe it sideways to dismiss.', 0))
          SButton({ text: 'Dismiss all', variant: 'ghost' }).onClick(() => SparkToast.dismissAll())
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
