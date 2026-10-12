import { LengthMetrics } from '@kit.ArkUI';
import {
  SButton, SCheckbox, SField, SFieldContent, SFieldDescription, SFieldError, SFieldGroup, SFieldLabel, SFieldLegend,
  SFieldSeparator, SFieldSet, SInput, SLabel, SProgress, SRadioGroup, SRadioGroupItem, SSlider, SSwitch, STextarea,
  SparkTheme, SparkUI
} from '@sparkui/core';
import { DemoBlock, DocHeader, DocSection } from '../shell/DocKit';

const space8: FlexSpaceOptions = { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) };
const space16: FlexSpaceOptions = { main: LengthMetrics.vp(16), cross: LengthMetrics.vp(16) };

// ------------------------------------------------------------------------------------------------ Input + Label

const INPUT_BASIC = `SInput({ placeholder: 'Email', inputType: 'email' })`;

const INPUT_LABEL = `Column({ space: 8 }) {
  SLabel({ text: 'Email', required: true })
  SInput({ placeholder: 'm@example.com', inputType: 'email' })
}`;

const INPUT_TYPES = `SInput({ placeholder: 'Password', inputType: 'password' })
SInput({ placeholder: 'Amount', inputType: 'number' })
SInput({ placeholder: 'Disabled', disabled: true })
SInput({ defaultValue: 'not-an-email', invalid: true })`;

const INPUT_SIZES = `SInput({ placeholder: 'Small', sizing: 'sm' })
SInput({ placeholder: 'Default' })
SInput({ placeholder: 'Large', sizing: 'lg' })`;

const INPUT_ADORNED = `SInput({ placeholder: 'Search…', icon: 'search', clearable: true })
SInput({ placeholder: 'Website', icon: 'globe', iconRight: 'external-link' })
SInput({ placeholder: 'Username', maxLength: 20, showCount: true, clearable: true })
SInput({ defaultValue: 'taken', icon: 'user', iconRight: 'circle-alert', invalid: true })`;

const INPUT_CONTROLLED = `@Local email: string = '';

SInput({ placeholder: 'Type something…', value: this.email!!,
  onSubmit: (v: string) => this.submitted = v })
Text(\`value = \${this.email}\`)`;

@ComponentV2
export struct InputDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local email: string = '';
  @Local submitted: string = '';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Input',
        lead: 'Displays a form input field. Pair it with SLabel, or use SField for label, description and error.'
      })
      DemoBlock({ code: INPUT_BASIC }) {
        Column() {
          SInput({ placeholder: 'Email', inputType: 'email' })
        }
        .width('100%')
        .constraintSize({ maxWidth: 320 })
      }
      DocSection({ title: 'With label', description: 'SLabel: text-sm font-medium leading-none.' })
      DemoBlock({ code: INPUT_LABEL }) {
        Column({ space: 8 }) {
          SLabel({ text: 'Email', required: true })
          SInput({ placeholder: 'm@example.com', inputType: 'email' })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 320 })
      }
      DocSection({ title: 'Types & states' })
      DemoBlock({ code: INPUT_TYPES }) {
        Column({ space: 12 }) {
          SInput({ placeholder: 'Password', inputType: 'password' })
          SInput({ placeholder: 'Amount', inputType: 'number' })
          SInput({ placeholder: 'Disabled', disabled: true })
          SInput({ defaultValue: 'not-an-email', invalid: true })
        }
        .width('100%')
        .constraintSize({ maxWidth: 320 })
      }
      DocSection({ title: 'Sizes', description: "sizing: 'sm' (32) | 'default' (36) | 'lg' (40)." })
      DemoBlock({ code: INPUT_SIZES }) {
        Column({ space: 12 }) {
          SInput({ placeholder: 'Small', sizing: 'sm' })
          SInput({ placeholder: 'Default' })
          SInput({ placeholder: 'Large', sizing: 'lg' })
        }
        .width('100%')
        .constraintSize({ maxWidth: 320 })
      }
      DocSection({
        title: 'Icons, clear button, counter',
        description: 'icon / iconRight, clearable (× while there is text) and showCount (length/maxLength).'
      })
      DemoBlock({ code: INPUT_ADORNED }) {
        Column({ space: 12 }) {
          SInput({ placeholder: 'Search…', icon: 'search', clearable: true })
          SInput({ placeholder: 'Website', icon: 'globe', iconRight: 'external-link' })
          SInput({ placeholder: 'Username', maxLength: 20, showCount: true, clearable: true })
          SInput({ defaultValue: 'taken', icon: 'user', iconRight: 'circle-alert', invalid: true })
        }
        .width('100%')
        .constraintSize({ maxWidth: 320 })
      }
      DocSection({ title: 'Controlled', description: 'Bind the value with !! like v-model.' })
      DemoBlock({ code: INPUT_CONTROLLED }) {
        Column({ space: 8 }) {
          SInput({
            placeholder: 'Type something…',
            value: this.email!!,
            clearable: true,
            onSubmit: (v: string) => {
              this.submitted = v;
            }
          })
          Row({ space: 8 }) {
            SButton({ text: 'Clear', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.email = '';
            })
            SButton({ text: 'Fill', variant: 'secondary', sizing: 'sm' }).onClick(() => {
              this.email = 'hello@sparkui.dev';
            })
          }
          Text(`value = ${this.email}   submitted = ${this.submitted}`)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 320 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Textarea

const TEXTAREA_CODE = `@Local message: string = '';

STextarea({ placeholder: 'Type your message here.', value: this.message!! })
STextarea({ placeholder: 'Disabled', disabled: true })
STextarea({ defaultValue: 'Too short', invalid: true, maxHeight: 160 })`;

const TEXTAREA_COUNT = `STextarea({ placeholder: 'Tell us about yourself', maxLength: 160, showCount: true })`;

@ComponentV2
export struct TextareaDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local message: string = '';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Textarea',
        lead: 'Displays a form textarea. It grows with its content (min-h-16); cap it with maxHeight.'
      })
      DemoBlock({ code: TEXTAREA_CODE }) {
        Column({ space: 12 }) {
          STextarea({ placeholder: 'Type your message here.', value: this.message!! })
          Text(`${this.message.length} characters`)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
          STextarea({ placeholder: 'Disabled', disabled: true })
          STextarea({ defaultValue: 'Too short', invalid: true, maxHeight: 160 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 360 })
      }
      DocSection({ title: 'Character counter', description: 'showCount draws length/maxLength in the corner.' })
      DemoBlock({ code: TEXTAREA_COUNT }) {
        Column() {
          STextarea({ placeholder: 'Tell us about yourself', maxLength: 160, showCount: true })
        }
        .width('100%')
        .constraintSize({ maxWidth: 360 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Checkbox

const CHECKBOX_BASIC = `SCheckbox({ label: 'Accept terms and conditions', checked: this.terms!! })
SCheckbox({ label: 'Enable notifications', defaultChecked: true })
SCheckbox({ label: 'Disabled', disabled: true })
SCheckbox({ label: 'Required', invalid: true })`;

const CHECKBOX_INDETERMINATE = `SCheckbox({
  label: 'Select all',
  checked: this.allChecked,
  indeterminate: this.someChecked && !this.allChecked,
  onCheckedChange: (v: boolean) => this.setAll(v)
})`;

const CHECKBOX_VARIANTS = `SCheckbox({ label: 'Small', sizing: 'sm', defaultChecked: true })
SCheckbox({ label: 'Large', sizing: 'lg', defaultChecked: true })
SCheckbox({ label: 'Accept terms', description: 'By clicking this you agree to our terms.' })
SCheckbox({ label: 'Enable notifications', description: 'You can enable or disable them at any time.',
  card: true, defaultChecked: true })`;

@ComponentV2
export struct CheckboxDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local terms: boolean = false;
  @Local a: boolean = true;
  @Local b: boolean = false;
  @Local c: boolean = false;

  @Computed
  get allChecked(): boolean {
    return this.a && this.b && this.c;
  }

  @Computed
  get someChecked(): boolean {
    return this.a || this.b || this.c;
  }

  private setAll(v: boolean): void {
    this.a = v;
    this.b = v;
    this.c = v;
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Checkbox',
        lead: 'A control that allows the user to toggle between checked and not checked.'
      })
      DemoBlock({ code: CHECKBOX_BASIC }) {
        Column({ space: 16 }) {
          SCheckbox({ label: 'Accept terms and conditions', checked: this.terms!! })
          SCheckbox({ label: 'Enable notifications', defaultChecked: true })
          SCheckbox({ label: 'Disabled', disabled: true })
          SCheckbox({ label: 'Required', invalid: true })
          Text(`terms = ${this.terms}`)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
        }
        .alignItems(HorizontalAlign.Start)
      }
      DocSection({ title: 'Indeterminate', description: 'A "select all" checkbox driven by its children.' })
      DemoBlock({ code: CHECKBOX_INDETERMINATE }) {
        Column({ space: 12 }) {
          SCheckbox({
            label: 'Select all',
            checked: this.allChecked,
            indeterminate: this.someChecked && !this.allChecked,
            onCheckedChange: (v: boolean) => this.setAll(v)
          })
          Column({ space: 12 }) {
            SCheckbox({ label: 'Recents', checked: this.a!! })
            SCheckbox({ label: 'Home', checked: this.b!! })
            SCheckbox({ label: 'Applications', checked: this.c!! })
          }
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 28 })
        }
        .alignItems(HorizontalAlign.Start)
      }
      DocSection({
        title: 'Sizes, description, card',
        description: "sizing: 'sm' | 'default' | 'lg'; card wraps label and description in a pressable bordered box."
      })
      DemoBlock({ code: CHECKBOX_VARIANTS }) {
        Column({ space: 16 }) {
          Row({ space: 24 }) {
            SCheckbox({ label: 'Small', sizing: 'sm', defaultChecked: true })
            SCheckbox({ label: 'Default', defaultChecked: true })
            SCheckbox({ label: 'Large', sizing: 'lg', defaultChecked: true })
          }
          SCheckbox({ label: 'Accept terms', description: 'By clicking this you agree to our terms and conditions.' })
          SCheckbox({
            label: 'Enable notifications',
            description: 'You can enable or disable notifications at any time.',
            card: true,
            defaultChecked: true
          })
          SCheckbox({ label: 'Weekly digest', description: 'A summary of activity every Monday.', card: true })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 400 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Switch

const SWITCH_CODE = `@Local airplane: boolean = false;

SSwitch({ label: 'Airplane Mode', checked: this.airplane!! })
SSwitch({ label: 'Wi-Fi', defaultChecked: true })
SSwitch({ label: 'Disabled', disabled: true })`;

const SWITCH_VARIANTS = `SSwitch({ label: 'Small', sizing: 'sm', defaultChecked: true })
SSwitch({ label: 'Large', sizing: 'lg', defaultChecked: true })
SSwitch({ label: 'Marketing emails', description: 'Receive emails about new products and features.',
  card: true })
SSwitch({ label: 'Security emails', description: 'Receive emails about your account security.',
  card: true, defaultChecked: true })`;

@ComponentV2
export struct SwitchDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local airplane: boolean = false;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Switch',
        lead: 'A control that allows the user to toggle between checked and not checked.'
      })
      DemoBlock({ code: SWITCH_CODE }) {
        Column({ space: 16 }) {
          SSwitch({ label: 'Airplane Mode', checked: this.airplane!! })
          SSwitch({ label: 'Wi-Fi', defaultChecked: true })
          SSwitch({ label: 'Disabled', disabled: true })
          SSwitch({ label: 'Disabled (on)', disabled: true, defaultChecked: true })
          Row({ space: 8 }) {
            SButton({ text: 'Toggle from outside', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.airplane = !this.airplane;
            })
            Text(`airplane = ${this.airplane}`)
              .fontSize(this.theme.text.xs)
              .fontColor(this.theme.colors.mutedForeground)
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
      DocSection({ title: 'Sizes & cards', description: 'A settings list built from card switches.' })
      DemoBlock({ code: SWITCH_VARIANTS }) {
        Column({ space: 16 }) {
          Row({ space: 24 }) {
            SSwitch({ label: 'Small', sizing: 'sm', defaultChecked: true })
            SSwitch({ label: 'Default', defaultChecked: true })
            SSwitch({ label: 'Large', sizing: 'lg', defaultChecked: true })
          }
          SSwitch({
            label: 'Marketing emails',
            description: 'Receive emails about new products, features, and more.',
            card: true
          })
          SSwitch({
            label: 'Security emails',
            description: 'Receive emails about your account security.',
            card: true,
            defaultChecked: true
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 420 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Radio Group

const RADIO_CODE = `@Local density: string = 'comfortable';

SRadioGroup({ value: this.density!! }) {
  SRadioGroupItem({ value: 'default', label: 'Default' })
  SRadioGroupItem({ value: 'comfortable', label: 'Comfortable' })
  SRadioGroupItem({ value: 'compact', label: 'Compact' })
}`;

const RADIO_HORIZONTAL = `SRadioGroup({ defaultValue: 'card', orientation: 'horizontal' }) {
  SRadioGroupItem({ value: 'card', label: 'Card' })
  SRadioGroupItem({ value: 'paypal', label: 'PayPal' })
  SRadioGroupItem({ value: 'apple', label: 'Apple Pay', disabled: true })
}
SRadioGroup({ defaultValue: 'a', disabled: true }) { ... }`;

const RADIO_CARDS = `SRadioGroup({ value: this.plan!! }) {
  SRadioGroupItem({ value: 'starter', label: 'Starter', description: 'For side projects · $0', card: true })
  SRadioGroupItem({ value: 'pro', label: 'Pro', description: 'For growing teams · $20 / month', card: true })
  SRadioGroupItem({ value: 'enterprise', label: 'Enterprise', description: 'Custom contracts', card: true })
}
SRadioGroup({ defaultValue: 'lg', orientation: 'horizontal' }) {
  SRadioGroupItem({ value: 'sm', label: 'Small', sizing: 'sm' })
  SRadioGroupItem({ value: 'lg', label: 'Large', sizing: 'lg' })
}`;

@ComponentV2
export struct RadioGroupDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local density: string = 'comfortable';
  @Local plan: string = 'pro';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Radio Group',
        lead: 'A set of checkable buttons, known as radio buttons, where no more than one can be checked at a time.'
      })
      DemoBlock({ code: RADIO_CODE }) {
        Column({ space: 16 }) {
          SRadioGroup({ value: this.density!! }) {
            SRadioGroupItem({ value: 'default', label: 'Default' })
            SRadioGroupItem({ value: 'comfortable', label: 'Comfortable' })
            SRadioGroupItem({ value: 'compact', label: 'Compact' })
          }
          Row({ space: 8 }) {
            SButton({ text: 'Reset', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.density = 'default';
            })
            Text(`density = ${this.density}`)
              .fontSize(this.theme.text.xs)
              .fontColor(this.theme.colors.mutedForeground)
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
      DocSection({ title: 'Horizontal & disabled', description: "orientation: 'vertical' | 'horizontal'" })
      DemoBlock({ code: RADIO_HORIZONTAL }) {
        Column({ space: 20 }) {
          SRadioGroup({ defaultValue: 'card', orientation: 'horizontal' }) {
            SRadioGroupItem({ value: 'card', label: 'Card' })
            SRadioGroupItem({ value: 'paypal', label: 'PayPal' })
            SRadioGroupItem({ value: 'apple', label: 'Apple Pay', disabled: true })
          }
          SRadioGroup({ defaultValue: 'a', disabled: true }) {
            SRadioGroupItem({ value: 'a', label: 'Disabled group (selected)' })
            SRadioGroupItem({ value: 'b', label: 'Disabled group' })
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
      DocSection({ title: 'Choice cards & sizes', description: 'card + description make a plan picker.' })
      DemoBlock({ code: RADIO_CARDS }) {
        Column({ space: 20 }) {
          SRadioGroup({ value: this.plan!! }) {
            SRadioGroupItem({ value: 'starter', label: 'Starter', description: 'For side projects · $0', card: true })
            SRadioGroupItem({
              value: 'pro',
              label: 'Pro',
              description: 'For growing teams · $20 / month',
              card: true
            })
            SRadioGroupItem({
              value: 'enterprise',
              label: 'Enterprise',
              description: 'Custom contracts and support',
              card: true
            })
          }
          SRadioGroup({ defaultValue: 'lg', orientation: 'horizontal' }) {
            SRadioGroupItem({ value: 'sm', label: 'Small', sizing: 'sm' })
            SRadioGroupItem({ value: 'md', label: 'Default' })
            SRadioGroupItem({ value: 'lg', label: 'Large', sizing: 'lg' })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 400 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Slider

const SLIDER_CODE = `@Local volume: number = 50;

SSlider({ value: this.volume!!, max: 100, step: 1 })
SSlider({ defaultValue: 0.3, min: 0, max: 1, step: 0.05 })
SSlider({ defaultValue: 25, disabled: true })`;

const SLIDER_RANGE = `@Local price: number[] = [200, 800];

SSlider({ values: this.price!!, min: 0, max: 1000, step: 10, tooltip: 'active',
  formatValue: (v: number) => \`$\${v}\` })`;

const SLIDER_MARKS = `SSlider({ defaultValue: 2, min: 0, max: 4, step: 1, ticks: true,
  marks: [0, 1, 2, 3, 4], formatValue: (v: number) => ['XS', 'S', 'M', 'L', 'XL'][v] })
SSlider({ defaultValue: 60, tooltip: 'always', formatValue: (v: number) => \`\${v}%\` })`;

const SLIDER_VERTICAL = `Row({ space: 32 }) {
  SSlider({ defaultValue: 40, orientation: 'vertical', length: 140 })
  SSlider({ defaultValues: [20, 70], orientation: 'vertical', length: 140, marks: [0, 50, 100] })
}`;

const SIZE_NAMES: string[] = ['XS', 'S', 'M', 'L', 'XL'];

@ComponentV2
export struct SliderDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local volume: number = 50;
  @Local opacityValue: number = 0.3;
  @Local committed: number = 50;
  @Local price: number[] = [200, 800];

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Slider',
        lead: 'An input where the user selects a value from within a given range. Drag the thumb, tap the track, ' +
          'or use the arrow keys when focused.'
      })
      DemoBlock({ code: SLIDER_CODE }) {
        Column({ space: 24 }) {
          SSlider({
            value: this.volume!!,
            max: 100,
            step: 1,
            label: 'Volume',
            onValueCommit: (v: number) => {
              this.committed = v;
            }
          })
          Text(`volume = ${this.volume}   committed = ${this.committed}`)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
          SSlider({ value: this.opacityValue!!, min: 0, max: 1, step: 0.05, label: 'Opacity' })
          Text(`opacity = ${this.opacityValue}`)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
          SSlider({ defaultValue: 25, disabled: true })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 360 })
      }
      DocSection({ title: 'Range', description: 'Two thumbs that never cross; the value bubble shows while dragging.' })
      DemoBlock({ code: SLIDER_RANGE }) {
        Column({ space: 16 }) {
          SSlider({
            values: this.price!!,
            min: 0,
            max: 1000,
            step: 10,
            tooltip: 'active',
            label: 'Price',
            formatValue: (v: number): string => `$${v}`
          })
          Text(`price = $${this.price[0]} – $${this.price[1]}`)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ top: 24 })
        .constraintSize({ maxWidth: 360 })
      }
      DocSection({ title: 'Ticks, marks & tooltip' })
      DemoBlock({ code: SLIDER_MARKS }) {
        Column({ space: 40 }) {
          SSlider({
            defaultValue: 2,
            min: 0,
            max: 4,
            step: 1,
            ticks: true,
            marks: [0, 1, 2, 3, 4],
            label: 'Size',
            formatValue: (v: number): string => SIZE_NAMES[v] ?? `${v}`
          })
          SSlider({ defaultValue: 60, tooltip: 'always', formatValue: (v: number): string => `${v}%` })
        }
        .width('100%')
        .padding({ top: 24 })
        .constraintSize({ maxWidth: 360 })
      }
      DocSection({ title: 'Vertical', description: "orientation: 'vertical' with a length; the value grows upward." })
      DemoBlock({ code: SLIDER_VERTICAL }) {
        Row({ space: 32 }) {
          SSlider({ defaultValue: 40, orientation: 'vertical', length: 140, label: 'Level' })
          SSlider({ defaultValues: [20, 70], orientation: 'vertical', length: 140, marks: [0, 50, 100] })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Progress

const PROGRESS_CODE = `@Local progress: number = 13;

aboutToAppear() {
  setTimeout(() => this.progress = 66, 500);
}

SProgress({ value: this.progress })`;

const PROGRESS_SIZES = `SProgress({ value: 40, sizing: 'sm' })
SProgress({ value: 55 })
SProgress({ value: 70, sizing: 'lg', showValue: true })
SProgress({ value: 30, thickness: 2 })`;

const PROGRESS_TONES = `SProgress({ value: 80, tone: 'success', showValue: true })
SProgress({ value: 55, tone: 'warning', showValue: true })
SProgress({ value: 35, tone: 'info', showValue: true })
SProgress({ value: 92, tone: 'destructive', valueText: '92 GB' })`;

const PROGRESS_STYLES = `SProgress({ value: 35, buffer: 70, sizing: 'sm' })      // buffered media
SProgress({ value: 60, sizing: 'lg', striped: true })
SProgress({ value: 45, sizing: 'lg', striped: true, animated: true, tone: 'info' })
SProgress({ value: 3, max: 5, segments: 5, valueText: 'Step 3 of 5' })
SProgress({ indeterminate: true, label: 'Loading' })`;

const PROGRESS_CIRCLE = `SProgress({ shape: 'circle', value: 72, sizing: 'sm' })
SProgress({ shape: 'circle', value: 72, showValue: true })
SProgress({ shape: 'circle', value: 72, sizing: 'lg', showValue: true, caption: 'Storage', tone: 'success' })
SProgress({ shape: 'circle', value: 4, max: 10, diameter: 80, thickness: 10 }) {
  Text('4/10')
}
SProgress({ shape: 'circle', indeterminate: true, sizing: 'sm' })`;

const PROGRESS_GAUGE = `SProgress({ shape: 'gauge', value: 48, showValue: true, caption: 'CPU', sizing: 'lg' })
SProgress({ shape: 'gauge', value: 82, valueText: '82°', caption: 'Temp', sizing: 'lg', tone: 'destructive' })`;

@ComponentV2
export struct ProgressDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local progress: number = 13;
  @Local busy: boolean = true;
  private timer: number = -1;

  aboutToAppear(): void {
    this.timer = setTimeout(() => {
      this.progress = 66;
    }, 500);
  }

  aboutToDisappear(): void {
    clearTimeout(this.timer);
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Progress',
        lead: 'Displays an indicator showing the completion progress of a task — as a bar, a segmented bar, a ring ' +
          'or a gauge.'
      })
      DemoBlock({ code: PROGRESS_CODE }) {
        Column({ space: 16 }) {
          SProgress({ value: this.progress, label: 'Upload' })
          Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center, space: space8 }) {
            SButton({ text: '-10', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.progress = Math.max(0, this.progress - 10);
            })
            SButton({ text: '+10', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.progress = Math.min(100, this.progress + 10);
            })
            Text(`${this.progress}%`)
              .fontSize(this.theme.text.xs)
              .fontColor(this.theme.colors.mutedForeground)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 360 })
      }
      DocSection({ title: 'Sizes', description: "sizing: 'sm' | 'default' | 'lg', or any thickness; showValue adds the percentage." })
      DemoBlock({ code: PROGRESS_SIZES }) {
        Column({ space: 16 }) {
          SProgress({ value: 40, sizing: 'sm' })
          SProgress({ value: 55 })
          SProgress({ value: 70, sizing: 'lg', showValue: true })
          SProgress({ value: 30, thickness: 2 })
        }
        .width('100%')
        .constraintSize({ maxWidth: 360 })
      }
      DocSection({ title: 'Tones', description: 'default | success | warning | info | destructive; valueText replaces the percentage.' })
      DemoBlock({ code: PROGRESS_TONES }) {
        Column({ space: 16 }) {
          SProgress({ value: 80, tone: 'success', showValue: true })
          SProgress({ value: 55, tone: 'warning', showValue: true })
          SProgress({ value: 35, tone: 'info', showValue: true })
          SProgress({ value: 92, tone: 'destructive', valueText: '92 GB' })
        }
        .width('100%')
        .constraintSize({ maxWidth: 360 })
      }
      DocSection({
        title: 'Buffer, stripes, steps, indeterminate',
        description: 'The indeterminate bar slides forever on its own node; toggle it to see it stop.'
      })
      DemoBlock({ code: PROGRESS_STYLES }) {
        Column({ space: 16 }) {
          SProgress({ value: this.progress / 2, buffer: this.progress, sizing: 'sm' })
          SProgress({ value: 60, sizing: 'lg', striped: true })
          SProgress({ value: this.progress, sizing: 'lg', striped: true, animated: true, tone: 'info' })
          SProgress({ value: 3, max: 5, segments: 5, valueText: 'Step 3 of 5' })
          SProgress({ value: this.progress, segments: 10, tone: 'success', sizing: 'sm' })
          SProgress({ indeterminate: this.busy, value: 100, label: 'Loading' })
          SButton({ text: this.busy ? 'Finish loading' : 'Restart', variant: 'outline', sizing: 'sm' })
            .onClick(() => {
              this.busy = !this.busy;
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 360 })
      }
      DocSection({ title: 'Circle', description: "shape: 'circle' — size, thickness, value / caption / custom centre, indeterminate spin." })
      DemoBlock({ code: PROGRESS_CIRCLE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center, space: space16 }) {
          SProgress({ shape: 'circle', value: this.progress, sizing: 'sm' })
          SProgress({ shape: 'circle', value: this.progress, showValue: true })
          SProgress({
            shape: 'circle',
            value: this.progress,
            sizing: 'lg',
            showValue: true,
            caption: 'Storage',
            tone: 'success'
          })
          SProgress({ shape: 'circle', value: 4, max: 10, diameter: 80, thickness: 10, tone: 'warning' }) {
            Text('4/10')
              .fontSize(this.theme.text.base)
              .fontWeight(this.theme.text.weightSemibold)
              .fontColor(this.theme.colors.foreground)
          }
          SProgress({ shape: 'circle', indeterminate: true, sizing: 'sm', label: 'Loading' })
        }
      }
      DocSection({ title: 'Gauge', description: "shape: 'gauge' — a 240° meter for levels and quotas." })
      DemoBlock({ code: PROGRESS_GAUGE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center, space: space16 }) {
          SProgress({ shape: 'gauge', value: this.progress, showValue: true, caption: 'CPU', sizing: 'lg' })
          SProgress({
            shape: 'gauge',
            value: 82,
            valueText: '82°',
            caption: 'Temp',
            sizing: 'lg',
            tone: 'destructive'
          })
          SProgress({ shape: 'gauge', value: 35, showValue: true, tone: 'info' })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Field

const FIELD_CODE = `SFieldSet() {
  SFieldLegend({ text: 'Profile' })
  SFieldDescription({ text: 'Fill in your public profile.' })
  SFieldGroup() {
    SField() {
      SFieldLabel({ text: 'Full name' })
      SInput({ placeholder: 'Evil Rabbit', value: this.name!! })
      SFieldDescription({ text: 'This appears on invoices and emails.' })
    }
    SField({ invalid: this.username.length < 3 }) {
      SFieldLabel({ text: 'Username' })
      SInput({ value: this.username!! })
      SFieldError({ text: this.username.length < 3 ? 'At least 3 characters.' : '' })
    }
  }
}`;

const FIELD_RESPONSIVE = `// label beside the control from 480vp of field width, stacked below
SField({ orientation: 'responsive' }) {
  SFieldContent() {
    SFieldLabel({ text: 'Name' })
    SFieldDescription({ text: 'Provide your full name for identification.' })
  }
  SInput({ placeholder: 'Evil Rabbit' })
}`;

const FIELD_HORIZONTAL = `SField({ orientation: 'horizontal' }) {
  SCheckbox({ checked: this.sync!! })
  SFieldLabel({ text: 'Sync across devices' })
}
SField({ orientation: 'horizontal' }) {
  SFieldContent() {
    SFieldLabel({ text: 'Multi-factor authentication' })
    SFieldDescription({ text: 'Enable MFA to secure your account.' })
  }
  SSwitch({ checked: this.mfa!! })
}`;

@ComponentV2
export struct FieldDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local name: string = '';
  @Local username: string = 'ab';
  @Local bio: string = '';
  @Local sync: boolean = true;
  @Local mfa: boolean = false;
  @Local plan: string = 'monthly';
  @Local narrow: boolean = false;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Field',
        lead: 'Combine labels, controls, and help text to compose accessible form fields. Responsive fields put the ' +
          'label beside the control when the field itself is at least 480vp wide — no breakpoints.'
      })
      DemoBlock({ code: FIELD_CODE, centered: false }) {
        Column() {
          SFieldSet() {
            SFieldLegend({ text: 'Profile' })
            SFieldDescription({ text: 'Fill in your public profile.' })
            SFieldGroup() {
              SField({ orientation: 'vertical' }) {
                SFieldLabel({ text: 'Full name' })
                SInput({ placeholder: 'Evil Rabbit', value: this.name!! })
                SFieldDescription({ text: 'This appears on invoices and emails.' })
              }
              SField({ orientation: 'vertical', invalid: this.username.length < 3 }) {
                SFieldLabel({ text: 'Username', required: true })
                SInput({ value: this.username!! })
                SFieldError({ text: this.username.length < 3 ? 'Username must be at least 3 characters.' : '' })
              }
              SField({ orientation: 'vertical' }) {
                SFieldLabel({ text: 'Bio' })
                STextarea({ placeholder: 'Tell us about yourself', value: this.bio!! })
              }
              SFieldSeparator()
              SField({ orientation: 'vertical' }) {
                SFieldLabel({ text: 'Billing' })
                SRadioGroup({ value: this.plan!! }) {
                  SRadioGroupItem({ value: 'monthly', label: 'Monthly ($9.99/month)' })
                  SRadioGroupItem({ value: 'yearly', label: 'Yearly ($99.99/year)' })
                }
              }
            }
          }
          Text(`name = ${this.name}   username = ${this.username}   plan = ${this.plan}`)
            .fontSize(this.theme.text.xs)
            .fontColor(this.theme.colors.mutedForeground)
            .margin({ top: 16 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 480 })
      }
      DocSection({
        title: 'Responsive',
        description: 'Resize the window (or narrow the demo) — the field measures its own width.'
      })
      DemoBlock({ code: FIELD_RESPONSIVE, centered: false }) {
        Column({ space: 16 }) {
          SButton({ text: this.narrow ? 'Make wide' : 'Make narrow', variant: 'outline', sizing: 'sm' })
            .onClick(() => {
              this.narrow = !this.narrow;
            })
          Column() {
            SFieldGroup() {
              SField() {
                SFieldContent() {
                  SFieldLabel({ text: 'Name' })
                  SFieldDescription({ text: 'Provide your full name for identification.' })
                }
                SInput({ placeholder: 'Evil Rabbit' })
              }
              SField() {
                SFieldContent() {
                  SFieldLabel({ text: 'Message' })
                  SFieldDescription({ text: 'You can write your message here.' })
                }
                STextarea({ placeholder: 'Hello, world!' })
              }
            }
          }
          .width(this.narrow ? 300 : '100%')
          .animation({ duration: this.theme.motion.durationNormal, curve: Curve.EaseOut })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      DocSection({ title: 'Horizontal', description: 'Checkbox, switch and label in a row.' })
      DemoBlock({ code: FIELD_HORIZONTAL, centered: false }) {
        Column() {
          SFieldGroup() {
            SField({ orientation: 'horizontal' }) {
              SCheckbox({ checked: this.sync!! })
              SFieldLabel({ text: 'Sync across devices' })
            }
            SField({ orientation: 'horizontal' }) {
              SFieldContent() {
                SFieldLabel({ text: 'Multi-factor authentication' })
                SFieldDescription({ text: 'Enable MFA to secure your account.' })
              }
              SSwitch({ checked: this.mfa!! })
            }
          }
          Flex({ wrap: FlexWrap.Wrap, space: space16 }) {
            Text(`sync = ${this.sync}`)
              .fontSize(this.theme.text.xs)
              .fontColor(this.theme.colors.mutedForeground)
            Text(`mfa = ${this.mfa}`)
              .fontSize(this.theme.text.xs)
              .fontColor(this.theme.colors.mutedForeground)
          }
          .margin({ top: 16 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 480 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
