import { LengthMetrics } from '@kit.ArkUI';
import {
  SButton, SColorPanel, SColorPicker, SField, SFieldDescription, SFieldGroup, SFieldLabel, SInput, SparkTheme, SparkUI
} from '@ospark/sparkui';
import { DemoBlock, DemoCaption, DocHeader, DocSection } from '../shell/DocKit';

const space12: FlexSpaceOptions = { main: LengthMetrics.vp(12), cross: LengthMetrics.vp(12) };

const PANEL_CODE = `@Local color: string = '#3b82f6';

SColorPanel({ value: this.color!! })`;

const FORM_CODE = `SFieldGroup() {
  SField() {
    SFieldLabel({ text: 'Project name' })
    SInput({ placeholder: 'Acme' })
  }
  SField() {
    SFieldLabel({ text: 'Brand color' })
    SColorPicker({ value: this.brand!!, triggerWidth: '100%' })
    SFieldDescription({ text: 'Used for buttons, links and highlights.' })
  }
}`;

const ALPHA_CODE = `// alpha slider over a checkerboard; HEX / RGB / HSL / OKLCH toggle for the input
SColorPanel({ value: this.tint!!, alpha: true, format: 'rgb', formatToggle: true })

// value format of a picker: 'hex' (default) | 'rgb' | 'hsl' | 'oklch'
SColorPicker({ defaultValue: '#8b5cf6', format: 'hsl' })
SColorPicker({ defaultValue: '#8b5cf680', format: 'oklch', alpha: true })`;

const SWATCH_CODE = `// custom presets + recently committed colours (shared by all pickers)
SColorPanel({
  value: this.accent!!,
  swatches: ['#0f172a', '#334155', '#64748b', '#e2e8f0', '#ef4444', '#f59e0b', '#22c55e', '#3b82f6'],
  recent: true
})

// compact: chip-only trigger, no input
SColorPicker({ value: this.accent!!, iconOnly: true, showInput: false, sizing: 'sm' })`;

const CONTROLLED_CODE = `@Local value: string = '#f43f5e';
@Local changes: number = 0;
@Local committed: string = '#f43f5e';

SColorPicker({
  value: this.value!!,
  onValueChange: () => this.changes++,          // live while dragging
  onValueCommit: (v: string) => this.committed = v  // on release / close
})
SButton({ text: 'Reset', variant: 'outline', sizing: 'sm' }).onClick(() => this.value = '#f43f5e')`;

@ComponentV2
export struct ColorPickerDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local color: string = '#3b82f6';
  @Local brand: string = '#0ea5e9';
  @Local tint: string = 'rgb(59 130 246 / 0.6)';
  @Local accent: string = '#3b82f6';
  @Local value: string = '#f43f5e';
  @Local changes: number = 0;
  @Local committed: string = '#f43f5e';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Color Picker',
        lead: 'Pick a colour with a saturation / brightness area, hue and alpha sliders, a validated input and ' +
          'preset swatches. SColorPanel is the inline panel; SColorPicker opens it from a trigger in a popover, ' +
          'or in a bottom sheet on compact touch screens.'
      })
      DemoBlock({ code: PANEL_CODE }) {
        Column({ space: 8 }) {
          SColorPanel({ value: this.color!! })
          DemoCaption({ text: `value: ${this.color}` })
        }
      }

      DocSection({
        title: 'Picker in a form',
        description: 'The trigger is an outline button with the colour chip and value; triggerWidth: \'100%\' ' +
          'fills the field.'
      })
      DemoBlock({ code: FORM_CODE }) {
        Column() {
          SFieldGroup() {
            SField() {
              SFieldLabel({ text: 'Project name' })
              SInput({ placeholder: 'Acme' })
            }
            SField() {
              SFieldLabel({ text: 'Brand color' })
              SColorPicker({ value: this.brand!!, triggerWidth: '100%' })
              SFieldDescription({ text: 'Used for buttons, links and highlights.' })
            }
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 360 })
      }

      DocSection({
        title: 'Alpha & formats',
        description: 'alpha adds an opacity slider; format sets the value format (hex, rgb, hsl, oklch) and ' +
          'formatToggle lets the input show any of them.'
      })
      DemoBlock({ code: ALPHA_CODE }) {
        Column({ space: 12 }) {
          SColorPanel({ value: this.tint!!, alpha: true, format: 'rgb', formatToggle: true })
          DemoCaption({ text: `value: ${this.tint}` })
          Flex({ wrap: FlexWrap.Wrap, space: space12, alignItems: ItemAlign.Center }) {
            SColorPicker({ defaultValue: '#8b5cf6', format: 'hsl' })
            SColorPicker({ defaultValue: '#8b5cf680', format: 'oklch', alpha: true })
          }
        }
      }

      DocSection({
        title: 'Swatches',
        description: 'swatches replaces the default palette ([] hides it); recent lists recently committed colours.'
      })
      DemoBlock({ code: SWATCH_CODE }) {
        Column({ space: 12 }) {
          SColorPanel({
            value: this.accent!!,
            swatches: ['#0f172a', '#334155', '#64748b', '#e2e8f0', '#ef4444', '#f59e0b', '#22c55e', '#3b82f6'],
            recent: true
          })
          Row({ space: 8 }) {
            SColorPicker({ value: this.accent!!, iconOnly: true, showInput: false, sizing: 'sm' })
            DemoCaption({ text: `accent: ${this.accent}` })
          }
          .alignItems(VerticalAlign.Center)
        }
      }

      DocSection({
        title: 'Controlled',
        description: 'onValueChange fires live while dragging; onValueCommit once on release and when the ' +
          'popover closes.'
      })
      DemoBlock({ code: CONTROLLED_CODE }) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            SColorPicker({
              value: this.value!!,
              onValueChange: () => {
                this.changes++;
              },
              onValueCommit: (v: string) => {
                this.committed = v;
              }
            })
            SButton({ text: 'Reset', variant: 'outline', sizing: 'sm' })
              .onClick(() => {
                this.value = '#f43f5e';
              })
          }
          .alignItems(VerticalAlign.Center)
          DemoCaption({ text: `value: ${this.value} · changes: ${this.changes} · committed: ${this.committed}` })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
