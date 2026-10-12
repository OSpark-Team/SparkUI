import {
  SBadge, SButton, SIcon, SInputGroup, SInputGroupAddon, SInputGroupButton, SInputGroupInput, SInputGroupText,
  SNumberField, SPinInput, SStepper, SStepperItem, STable, STableBody, STableCell, STableColumn, STableFooter,
  STableHead, STableHeader, STableRow, STagsInput, SparkTheme, SparkUI
} from '@sparkui/core';
import { DemoBlock, DemoCaption, DocHeader, DocSection } from '../shell/DocKit';

// ------------------------------------------------------------------------------------------------ InputGroup

const IG_BASIC = `SInputGroup() {
  SInputGroupAddon() { SIcon({ name: 'search' }) }
  SInputGroupInput({ placeholder: 'Search…' })
  SInputGroupAddon({ alignment: 'inline-end' }) {
    SInputGroupText({ text: '12 results' })
  }
}`;

const IG_TEXT = `SInputGroup() {
  SInputGroupAddon() { SInputGroupText({ text: 'https://' }) }
  SInputGroupInput({ placeholder: 'example.com' })
  SInputGroupAddon({ alignment: 'inline-end' }) { SInputGroupText({ text: '.com' }) }
}
SInputGroup() {
  SInputGroupAddon() { SInputGroupText({ text: '$' }) }
  SInputGroupInput({ placeholder: '0.00', inputType: 'number' })
  SInputGroupAddon({ alignment: 'inline-end' }) { SInputGroupText({ text: 'USD' }) }
}`;

const IG_BUTTON = `@Local url: string = 'https://sparkui.dev';

SInputGroup() {
  SInputGroupInput({ value: this.url!! })
  SInputGroupAddon({ alignment: 'inline-end' }) {
    SInputGroupButton({ icon: 'copy', sizing: 'icon-xs', label: 'Copy' })
      .onClick(() => this.copied = true)
  }
}
SInputGroup() {
  SInputGroupInput({ placeholder: 'Type to search…' })
  SInputGroupAddon({ alignment: 'inline-end' }) {
    SInputGroupButton({ text: 'Search', variant: 'secondary' })
  }
}`;

const IG_BLOCK = `SInputGroup() {
  SInputGroupAddon({ alignment: 'block-start' }) {
    SInputGroupText({ icon: 'file-text', text: 'script.ts' })
  }
  SInputGroupInput({ placeholder: 'console.log("Hello")' })
  SInputGroupAddon({ alignment: 'block-end' }) {
    SInputGroupText({ text: 'Line 1, Column 1' })
  }
}
SInputGroup({ invalid: true }) {
  SInputGroupAddon() { SIcon({ name: 'mail' }) }
  SInputGroupInput({ placeholder: 'Email' })
}`;

@ComponentV2
export struct InputGroupDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local url: string = 'https://sparkui.dev';
  @Local copied: number = 0;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Input Group',
        lead: 'Add icons, text or buttons to an input. The group draws the border and shows the focus ring ' +
          'while its input is focused; tapping an addon focuses the input.'
      })
      DemoBlock({ code: IG_BASIC }) {
        Column() {
          SInputGroup() {
            SInputGroupAddon() {
              SIcon({ name: 'search', sizing: 16, color: this.theme.colors.mutedForeground })
            }
            SInputGroupInput({ placeholder: 'Search…' })
            SInputGroupAddon({ alignment: 'inline-end' }) {
              SInputGroupText({ text: '12 results' })
            }
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 360 })
      }
      DocSection({ title: 'Text', description: 'Prefixes and suffixes with SInputGroupText.' })
      DemoBlock({ code: IG_TEXT }) {
        Column({ space: 12 }) {
          SInputGroup() {
            SInputGroupAddon() {
              SInputGroupText({ text: 'https://' })
            }
            SInputGroupInput({ placeholder: 'example.com' })
            SInputGroupAddon({ alignment: 'inline-end' }) {
              SInputGroupText({ text: '.com' })
            }
          }
          SInputGroup() {
            SInputGroupAddon() {
              SInputGroupText({ text: '$' })
            }
            SInputGroupInput({ placeholder: '0.00', inputType: 'number' })
            SInputGroupAddon({ alignment: 'inline-end' }) {
              SInputGroupText({ text: 'USD' })
            }
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 360 })
      }
      DocSection({ title: 'Button', description: 'Compact buttons inside the field (xs, sm, icon-xs, icon-sm).' })
      DemoBlock({ code: IG_BUTTON }) {
        Column({ space: 12 }) {
          SInputGroup() {
            SInputGroupInput({ value: this.url!! })
            SInputGroupAddon({ alignment: 'inline-end' }) {
              SInputGroupButton({ icon: 'copy', sizing: 'icon-xs', label: 'Copy' })
                .onClick(() => {
                  this.copied++;
                })
            }
          }
          SInputGroup() {
            SInputGroupInput({ placeholder: 'Type to search…' })
            SInputGroupAddon({ alignment: 'inline-end' }) {
              SInputGroupButton({ text: 'Search', variant: 'secondary' })
            }
          }
          Text(`value = ${this.url}   copy taps = ${this.copied}`)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 360 })
      }
      DocSection({ title: 'Block addons & invalid', description: 'block-start / block-end span the full width.' })
      DemoBlock({ code: IG_BLOCK }) {
        Column({ space: 12 }) {
          SInputGroup() {
            SInputGroupAddon({ alignment: 'block-start' }) {
              SInputGroupText({ icon: 'file-text', text: 'script.ts' })
            }
            SInputGroupInput({ placeholder: 'console.log("Hello")' })
            SInputGroupAddon({ alignment: 'block-end' }) {
              SInputGroupText({ text: 'Line 1, Column 1' })
            }
          }
          SInputGroup({ invalid: true }) {
            SInputGroupAddon() {
              SIcon({ name: 'mail', sizing: 16, color: this.theme.colors.mutedForeground })
            }
            SInputGroupInput({ placeholder: 'Email' })
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 360 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ NumberField

const NF_BASIC = `@Local qty: number = 3;

SNumberField({ value: this.qty!!, min: 0, max: 10 })
Text(\`value = \${this.qty}\`)`;

const NF_DECIMALS = `SNumberField({ defaultValue: 1.5, step: 0.25, decimals: 2, min: 0 })
SNumberField({ defaultValue: 18, min: 0, max: 100, invalid: true })
SNumberField({ defaultValue: 5, disabled: true })`;

@ComponentV2
export struct NumberFieldDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local qty: number = 3;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Number Field',
        lead: 'An input for numbers with decrement / increment buttons. Hold a button to repeat; arrow up / down ' +
          'step with a keyboard; typed values are clamped on Enter or blur.'
      })
      DemoBlock({ code: NF_BASIC }) {
        Column({ space: 8 }) {
          SNumberField({ value: this.qty!!, min: 0, max: 10, label: 'Quantity' })
          Row({ space: 8 }) {
            SButton({ text: 'Reset', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.qty = 0;
            })
            SButton({ text: 'Set 7', variant: 'secondary', sizing: 'sm' }).onClick(() => {
              this.qty = 7;
            })
          }
          Text(`value = ${this.qty}`)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 220 })
      }
      DocSection({ title: 'Step, decimals & states' })
      DemoBlock({ code: NF_DECIMALS }) {
        Column({ space: 12 }) {
          SNumberField({ defaultValue: 1.5, step: 0.25, decimals: 2, min: 0 })
          SNumberField({ defaultValue: 18, min: 0, max: 100, invalid: true })
          SNumberField({ defaultValue: 5, disabled: true })
        }
        .width('100%')
        .constraintSize({ maxWidth: 220 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ PinInput

const PIN_BASIC = `@Local code: string = '';

SPinInput({ value: this.code!!, onComplete: (v: string) => this.completed = v })
Text(\`value = \${this.code}\`)`;

const PIN_VARIANTS = `SPinInput({ length: 6, groups: [3, 3] })
SPinInput({ length: 4, masked: true })
SPinInput({ length: 6, pattern: 'alphanumeric', invalid: true })
SPinInput({ length: 4, defaultValue: '12', disabled: true })`;

@ComponentV2
export struct PinInputDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local code: string = '';
  @Local completed: string = '';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Pin Input',
        lead: 'Accessible one-time-password input (shadcn InputOTP look). One hidden text field captures typing ' +
          'and paste; the slots show the characters and a blinking caret.'
      })
      DemoBlock({ code: PIN_BASIC }) {
        Column({ space: 8 }) {
          SPinInput({
            value: this.code!!,
            onComplete: (v: string) => {
              this.completed = v;
            }
          })
          Row({ space: 8 }) {
            SButton({ text: 'Clear', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.code = '';
              this.completed = '';
            })
            SButton({ text: 'Fill 424242', variant: 'secondary', sizing: 'sm' }).onClick(() => {
              this.code = '424242';
            })
          }
          Text(`value = ${this.code}   completed = ${this.completed}`)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      DocSection({ title: 'Groups, mask & pattern', description: 'Slots shrink (36 → 28vp) when space is tight.' })
      DemoBlock({ code: PIN_VARIANTS }) {
        Column({ space: 12 }) {
          SPinInput({ length: 6, groups: [3, 3] })
          SPinInput({ length: 4, masked: true })
          SPinInput({ length: 6, pattern: 'alphanumeric', invalid: true })
          SPinInput({ length: 4, defaultValue: '12', disabled: true })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ TagsInput

const TAGS_BASIC = `@Local tags: string[] = ['Vue', 'ArkTS'];

STagsInput({ value: this.tags!!, placeholder: 'Add a framework…' })
Text(\`value = \${this.tags.join(', ')}\`)`;

const TAGS_OPTIONS = `STagsInput({ defaultValue: ['one', 'two'], max: 3, placeholder: 'Max 3 tags' })
STagsInput({ delimiter: ';', placeholder: 'Separate with ;' })
STagsInput({ defaultValue: ['locked'], disabled: true })`;

@ComponentV2
export struct TagsInputDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local tags: string[] = ['Vue', 'ArkTS'];

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Tags Input',
        lead: 'Tag chips with an inline input. Enter or the delimiter adds a tag, Backspace in the empty input ' +
          'removes the last one; chips wrap onto new lines.'
      })
      DemoBlock({ code: TAGS_BASIC }) {
        Column({ space: 8 }) {
          STagsInput({ value: this.tags!!, placeholder: 'Add a framework…' })
          Row({ space: 8 }) {
            SButton({ text: 'Clear', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.tags = [];
            })
            SButton({ text: 'Add React', variant: 'secondary', sizing: 'sm' }).onClick(() => {
              if (this.tags.indexOf('React') < 0) {
                this.tags = this.tags.concat(['React']);
              }
            })
          }
          Text(`value = [${this.tags.join(', ')}]`)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 400 })
      }
      DocSection({ title: 'Max, delimiter & disabled' })
      DemoBlock({ code: TAGS_OPTIONS }) {
        Column({ space: 12 }) {
          STagsInput({ defaultValue: ['one', 'two'], max: 3, placeholder: 'Max 3 tags' })
          STagsInput({ delimiter: ';', placeholder: 'Separate with ;' })
          STagsInput({ defaultValue: ['locked'], disabled: true })
        }
        .width('100%')
        .constraintSize({ maxWidth: 400 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Stepper

const STEPPER_BASIC = `@Local step: number = 2;

SStepper({ value: this.step!! }) {
  SStepperItem({ step: 1, title: 'Address', description: 'Where to ship' })
  SStepperItem({ step: 2, title: 'Shipping', description: 'Pick a carrier' })
  SStepperItem({ step: 3, title: 'Payment', description: 'Card or wallet' })
  SStepperItem({ step: 4, title: 'Review' })
}
SButton({ text: 'Next' }).onClick(() => this.step = Math.min(4, this.step + 1))`;

const STEPPER_VERTICAL = `SStepper({ defaultValue: 2, orientation: 'vertical', linear: false }) {
  SStepperItem({ step: 1, title: 'Create account', description: 'Email and password' })
  SStepperItem({ step: 2, title: 'Verify email', description: 'Enter the 6-digit code we sent you' })
  SStepperItem({ step: 3, title: 'Invite team', disabled: true })
}`;

@ComponentV2
export struct StepperDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local step: number = 2;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Stepper',
        lead: 'A set of steps used to indicate progress. Responsive by default: horizontal when every step gets ' +
          '140vp, vertical otherwise. Tap a step to go back (or to the next one).'
      })
      DemoBlock({ code: STEPPER_BASIC }) {
        Column({ space: 16 }) {
          SStepper({ value: this.step!! }) {
            SStepperItem({ step: 1, title: 'Address', description: 'Where to ship' })
            SStepperItem({ step: 2, title: 'Shipping', description: 'Pick a carrier' })
            SStepperItem({ step: 3, title: 'Payment', description: 'Card or wallet' })
            SStepperItem({ step: 4, title: 'Review' })
          }
          Row({ space: 8 }) {
            SButton({ text: 'Back', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.step = Math.max(1, this.step - 1);
            })
            SButton({ text: 'Next', sizing: 'sm' }).onClick(() => {
              this.step = Math.min(5, this.step + 1);
            })
            Text(`value = ${this.step}`)
              .fontSize(this.theme.text.xs)
              .fontColor(this.theme.colors.mutedForeground)
          }
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      DocSection({ title: 'Vertical', description: 'linear: false lets the user jump to any step.' })
      DemoBlock({ code: STEPPER_VERTICAL, centered: false }) {
        SStepper({ defaultValue: 2, orientation: 'vertical', linear: false }) {
          SStepperItem({ step: 1, title: 'Create account', description: 'Email and password' })
          SStepperItem({ step: 2, title: 'Verify email', description: 'Enter the 6-digit code we sent you' })
          SStepperItem({ step: 3, title: 'Invite team', disabled: true })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Table

class Invoice {
  invoice: string;
  status: string;
  method: string;
  amount: string;

  constructor(invoice: string, status: string, method: string, amount: string) {
    this.invoice = invoice;
    this.status = status;
    this.method = method;
    this.amount = amount;
  }
}

const INVOICES: Invoice[] = [
  new Invoice('INV001', 'Paid', 'Credit Card', '$250.00'),
  new Invoice('INV002', 'Pending', 'PayPal', '$150.00'),
  new Invoice('INV003', 'Unpaid', 'Bank Transfer', '$350.00'),
  new Invoice('INV004', 'Paid', 'Credit Card', '$450.00'),
  new Invoice('INV005', 'Paid', 'PayPal', '$550.00'),
  new Invoice('INV006', 'Pending', 'Bank Transfer', '$200.00'),
  new Invoice('INV007', 'Unpaid', 'Credit Card', '$300.00')
];

const INVOICE_COLUMNS: STableColumn[] = [
  new STableColumn('invoice', 'Invoice', { fixedWidth: 100 }),
  new STableColumn('status', 'Status'),
  new STableColumn('method', 'Method', { weight: 1.5, minWidth: 120 }),
  new STableColumn('amount', 'Amount', { alignment: 'end', minWidth: 90 })
];

const TABLE_SLOTS = `const columns: STableColumn[] = [
  new STableColumn('invoice', 'Invoice', { fixedWidth: 100 }),
  new STableColumn('status', 'Status'),
  new STableColumn('method', 'Method', { weight: 1.5, minWidth: 120 }),
  new STableColumn('amount', 'Amount', { alignment: 'end', minWidth: 90 })
];

STable({ columns: columns, caption: 'A list of your recent invoices.' }) {
  STableHeader() {
    STableRow() {
      STableHead({ text: 'Invoice' })
      STableHead({ text: 'Status' })
      STableHead({ text: 'Method' })
      STableHead({ text: 'Amount' })
    }
  }
  STableBody() {
    ForEach(INVOICES, (r: Invoice) => {
      STableRow() {
        STableCell({ text: r.invoice })
        STableCell() { SBadge({ text: r.status, variant: 'outline' }) }
        STableCell({ text: r.method })
        STableCell({ text: r.amount })
      }
    }, (r: Invoice) => r.invoice)
  }
  STableFooter() {
    STableRow() {
      STableCell({ text: 'Total' })
      STableCell()
      STableCell()
      STableCell({ text: '$2,500.00' })
    }
  }
}`;

const TABLE_DATA = `STable({
  columns: columns,
  adaptive: 'table',   // never cards: scrolls horizontally when too narrow
  rows: [
    ['INV001', 'Paid', 'Credit Card', '$250.00'],
    ['INV002', 'Pending', 'PayPal', '$150.00'],
    ['INV003', 'Unpaid', 'Bank Transfer', '$350.00']
  ],
  footer: ['Total', '', '', '$750.00']
})`;

const BIG_STATUSES: string[] = ['Paid', 'Pending', 'Unpaid', 'Refunded'];
const BIG_METHODS: string[] = ['Credit Card', 'PayPal', 'Bank Transfer', 'Apple Pay', 'Alipay'];

/** 10 000 generated invoices for the virtualized data table. */
function bigInvoices(count: number): string[][] {
  const out: string[][] = [];
  for (let i = 0; i < count; i++) {
    const cents = ((i * 7919) % 100000) + 500;
    out.push([`INV${String(i + 1).padStart(5, '0')}`, BIG_STATUSES[i % 4], BIG_METHODS[(i * 3) % 5],
      `$${Math.floor(cents / 100)}.${String(cents % 100).padStart(2, '0')}`]);
  }
  return out;
}

const BIG_ROWS: string[][] = bigInvoices(10000);

const TABLE_BIG = `// 10 000 rows: the body is a List + Repeat.virtualScroll(), so only the rows in view
// are built; it scrolls inside a 400vp viewport under a fixed header.
STable({
  columns: columns,
  rows: BIG_ROWS,                 // string[][] with 10 000 entries
  bodyHeight: 400,
  rowKey: (r: string[]) => r[0],  // invoice number: stable across inserts / sorting
  footer: ['10 000 invoices', '', '', '']
})`;

@ComponentV2
export struct TableDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  /** demo wrapper width: 0 = full width */
  @Local demoWidth: number = 0;
  @Local selected: string = 'INV002';

  @Computed
  get frameWidth(): Length {
    return this.demoWidth > 0 ? this.demoWidth : '100%';
  }

  @Builder
  widthSwitch() {
    Row({ space: 4 }) {
      SButton({ text: 'Full', variant: this.demoWidth === 0 ? 'secondary' : 'ghost', sizing: 'sm' })
        .onClick(() => {
          this.demoWidth = 0;
        })
      SButton({ text: '420', variant: this.demoWidth === 420 ? 'secondary' : 'ghost', sizing: 'sm' })
        .onClick(() => {
          this.demoWidth = 420;
        })
      SButton({ text: '300', variant: this.demoWidth === 300 ? 'secondary' : 'ghost', sizing: 'sm' })
        .onClick(() => {
          this.demoWidth = 300;
        })
    }
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Table',
        lead: 'A responsive table. Columns are fixed or weighted; when the table is narrower than its columns\' ' +
          'minimum widths, every row becomes a card of "Head: value" lines (adaptive: \'auto\').'
      })
      DemoBlock({ code: TABLE_SLOTS, centered: false }) {
        Column({ space: 12 }) {
          this.widthSwitch()
          Text('Narrow the frame below 372vp to see the card layout. Tap a row to select it.')
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
          Column() {
            STable({ columns: INVOICE_COLUMNS, caption: 'A list of your recent invoices.' }) {
              STableHeader() {
                STableRow() {
                  STableHead({ text: 'Invoice' })
                  STableHead({ text: 'Status' })
                  STableHead({ text: 'Method' })
                  STableHead({ text: 'Amount' })
                }
              }
              STableBody() {
                ForEach(INVOICES, (r: Invoice) => {
                  Column() {
                    STableRow({ selected: this.selected === r.invoice }) {
                      STableCell({ text: r.invoice })
                      STableCell() {
                        SBadge({ text: r.status, variant: r.status === 'Paid' ? 'secondary' : 'outline' })
                      }
                      STableCell({ text: r.method })
                      STableCell({ text: r.amount })
                    }
                  }
                  .width('100%')
                  .onClick(() => {
                    this.selected = r.invoice;
                  })
                }, (r: Invoice) => r.invoice)
              }
              STableFooter() {
                STableRow() {
                  STableCell({ text: 'Total' })
                  STableCell()
                  STableCell()
                  STableCell({ text: '$2,500.00' })
                }
              }
            }
          }
          .width(this.frameWidth)
          .padding(8)
          .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusMd })
          Text(`selected = ${this.selected}`)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      DocSection({
        title: 'Data form',
        description: 'Pass rows: string[][] (and footer) instead of slots. adaptive: \'table\' keeps the table ' +
          'and scrolls horizontally when it does not fit.'
      })
      DemoBlock({ code: TABLE_DATA, centered: false }) {
        Column({ space: 12 }) {
          this.widthSwitch()
          Column() {
            STable({
              columns: INVOICE_COLUMNS,
              adaptive: 'table',
              rows: [
                ['INV001', 'Paid', 'Credit Card', '$250.00'],
                ['INV002', 'Pending', 'PayPal', '$150.00'],
                ['INV003', 'Unpaid', 'Bank Transfer', '$350.00']
              ],
              footer: ['Total', '', '', '$750.00']
            })
          }
          .width(this.frameWidth)
          .padding(8)
          .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusMd })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      DocSection({
        title: 'Large data',
        description: 'The data form is virtualized (List + Repeat.virtualScroll()): only the rows in view exist and ' +
          'scrolled-out rows are reused, so 10 000 rows open and scroll like 10. Narrow the frame to see the ' +
          'virtualized card layout.'
      })
      DemoBlock({ code: TABLE_BIG, centered: false }) {
        Column({ space: 12 }) {
          this.widthSwitch()
          Column() {
            STable({
              columns: INVOICE_COLUMNS,
              rows: BIG_ROWS,
              bodyHeight: 400,
              rowKey: (r: string[]) => r[0],
              footer: [`${BIG_ROWS.length} invoices`, '', '', '']
            })
          }
          .width(this.frameWidth)
          .padding(8)
          .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusMd })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      DemoCaption({ text: `${BIG_ROWS.length} rows · frame = ${this.demoWidth > 0 ? this.demoWidth + 'vp' : 'full'}` })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
