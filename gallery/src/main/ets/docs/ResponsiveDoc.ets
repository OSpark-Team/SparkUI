import {
  SButton, SCard, SCardContent, SCardDescription, SCardFooter, SCardHeader, SCardTitle, SCodeBlock, SColumn,
  SColumns, SFlow, SGrid, SGridItem, SIcon, SStack, SparkColor, SparkTheme, SparkUI
} from '@sparkui/core';
import { DocHeader, DocSection } from '../shell/DocKit';

const CODE = `SGrid({ minItemWidth: 200 }) {          // no breakpoints: columns follow the width
  SGridItem() { StatCard(...) }
  SGridItem() { StatCard(...) }
  SGridItem({ span: 2 }) { ... }        // spans 2 columns when there are 2+
}

SColumns({ minColumnWidth: 280 }) {     // side by side, or stacked when narrow
  SColumn({ weight: 2 }) { SCard() { ... } }
  SColumn() { SCard() { ... } }
}`;

class Stat {
  title: string;
  value: string;
  delta: string;
  icon: string;

  constructor(title: string, value: string, delta: string, icon: string) {
    this.title = title;
    this.value = value;
    this.delta = delta;
    this.icon = icon;
  }
}

const STATS: Stat[] = [
  new Stat('Total Revenue', '$45,231.89', '+20.1% from last month', 'dollar-sign'),
  new Stat('Subscriptions', '+2,350', '+180.1% from last month', 'users'),
  new Stat('Sales', '+12,234', '+19% from last month', 'credit-card'),
  new Stat('Active Now', '+573', '+201 since last hour', 'activity')
];

const BARS: number[] = [42, 68, 51, 80, 63, 90, 74, 58, 85, 67, 95, 72];

@ComponentV2
struct StatCard {
  @Param stat: Stat = STATS[0];
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    SCard() {
      SCardContent() {
        Row() {
          Text(this.stat.title)
            .fontSize(this.theme.text.sm)
            .fontWeight(this.theme.text.weightMedium)
            .fontColor(this.theme.colors.cardForeground)
          SIcon({ name: this.stat.icon, sizing: 16, color: this.theme.colors.mutedForeground })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)

        Text(this.stat.value)
          .fontSize(this.theme.text.xxl)
          .fontWeight(this.theme.text.weightBold)
          .fontColor(this.theme.colors.cardForeground)
        Text(this.stat.delta)
          .fontSize(this.theme.text.xs)
          .fontColor(this.theme.colors.mutedForeground)
      }
    }
  }
}

@ComponentV2
export struct ResponsiveDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local widthPct: number = 100;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Responsive Layout',
        lead: 'No breakpoints to learn. Stack components the way you would on the web — SGrid, SColumns, SFlow and ' +
          'every SparkUI component measure the space they actually get and lay themselves out.'
      })
      SCodeBlock({ code: CODE, language: 'arkts' })

      DocSection({
        title: 'Try it',
        description: 'Drag to resize the container (like resizing a browser window). Nothing below declares a breakpoint.'
      })
      Row({ space: 12 }) {
        SIcon({ name: 'smartphone', sizing: 16, color: this.theme.colors.mutedForeground })
        Slider({ value: this.widthPct, min: 28, max: 100, step: 1 })
          .layoutWeight(1)
          .onChange((v: number) => {
            this.widthPct = v;
          })
        SIcon({ name: 'monitor', sizing: 16, color: this.theme.colors.mutedForeground })
        Text(`${Math.round(this.widthPct)}%`)
          .width(44)
          .fontSize(this.theme.text.sm)
          .fontColor(this.theme.colors.mutedForeground)
      }
      .width('100%')

      Column() {
        SStack({ gap: 16 }) {
          SGrid({ minItemWidth: 200 }) {
            ForEach(STATS, (s: Stat) => {
              SGridItem() {
                StatCard({ stat: s })
              }
            }, (s: Stat) => s.title)
          }

          SColumns({ minColumnWidth: 260, gap: 16 }) {
            SColumn({ weight: 2 }) {
              SCard() {
                SCardHeader() {
                  SCardTitle({ text: 'Overview' })
                  SCardDescription({ text: 'Monthly revenue' })
                }
                SCardContent() {
                  Row({ space: 6 }) {
                    ForEach(BARS, (b: number, i: number) => {
                      Column()
                        .layoutWeight(1)
                        .height(b * 1.6)
                        .borderRadius({ topLeft: 4, topRight: 4 })
                        .backgroundColor(i === 10 ? this.theme.colors.primary :
                          SparkColor.alpha(this.theme.colors.primary, 0.35))
                    }, (b: number, i: number) => `${i}`)
                  }
                  .width('100%')
                  .height(160)
                  .alignItems(VerticalAlign.Bottom)
                }
              }
            }

            SColumn() {
              SCard() {
                SCardHeader() {
                  SCardTitle({ text: 'Recent Sales' })
                  SCardDescription({ text: 'You made 265 sales this month.' })
                }
                SCardContent() {
                  ForEach(['Olivia Martin', 'Jackson Lee', 'Isabella Nguyen'], (n: string) => {
                    Row({ space: 12 }) {
                      Text(n.split(' ').map((p: string) => p.charAt(0)).join(''))
                        .width(36)
                        .height(36)
                        .textAlign(TextAlign.Center)
                        .borderRadius(18)
                        .fontSize(this.theme.text.sm)
                        .backgroundColor(this.theme.colors.muted)
                        .fontColor(this.theme.colors.foreground)
                      Text(n)
                        .layoutWeight(1)
                        .fontSize(this.theme.text.sm)
                        .fontWeight(this.theme.text.weightMedium)
                        .fontColor(this.theme.colors.cardForeground)
                      Text('+$1,999')
                        .fontSize(this.theme.text.sm)
                        .fontWeight(this.theme.text.weightMedium)
                        .fontColor(this.theme.colors.cardForeground)
                    }
                    .width('100%')
                  }, (n: string) => n)
                }
              }
            }
          }

          SCard() {
            SCardHeader() {
              SCardTitle({ text: 'Create project' })
              SCardDescription({ text: 'Fields sit side by side when there is room, and stack otherwise.' })
            }
            SCardContent() {
              SColumns({ minColumnWidth: 220, gap: 12 }) {
                SColumn() {
                  Text('Name').fontSize(this.theme.text.sm).fontWeight(this.theme.text.weightMedium)
                    .fontColor(this.theme.colors.foreground)
                  TextInput({ placeholder: 'Name of your project' })
                }
                SColumn() {
                  Text('Framework').fontSize(this.theme.text.sm).fontWeight(this.theme.text.weightMedium)
                    .fontColor(this.theme.colors.foreground)
                  TextInput({ placeholder: 'ArkUI' })
                }
              }
            }
            SCardFooter() {
              SButton({ text: 'Cancel', variant: 'outline' })
              SButton({ text: 'Deploy' })
            }
          }

          SFlow() {
            ForEach(['Design', 'Engineering', 'Marketing', 'Sales', 'Support', 'Operations', 'Finance'],
              (t: string) => {
                Text(t)
                  .fontSize(this.theme.text.xs)
                  .fontWeight(this.theme.text.weightMedium)
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .borderRadius(this.theme.radiusMd)
                  .backgroundColor(this.theme.colors.secondary)
                  .fontColor(this.theme.colors.secondaryForeground)
              }, (t: string) => t)
          }
        }
      }
      .width(`${this.widthPct}%`)
      .padding(12)
      .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusLg, style: BorderStyle.Dashed })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
