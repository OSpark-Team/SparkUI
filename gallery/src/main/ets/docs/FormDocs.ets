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
      DocSection({ title: 'Controlled', description: 'Bind the value with !! like v-model.' })
      DemoBlock({ code: INPUT_CONTROLLED }) {
        Column({ space: 8 }) {
          SInput({
            placeholder: 'Type something…',
            value: this.email!!,
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

@ComponentV2
export struct RadioGroupDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local density: string = 'comfortable';

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

@ComponentV2
export struct SliderDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local volume: number = 50;
  @Local opacityValue: number = 0.3;
  @Local committed: number = 50;

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

@ComponentV2
export struct ProgressDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local progress: number = 13;
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
        lead: 'Displays an indicator showing the completion progress of a task, typically displayed as a progress bar.'
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
