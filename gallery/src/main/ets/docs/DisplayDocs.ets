import { LengthMetrics } from '@kit.ArkUI';
import {
  SAlert, SAlertDescription, SAlertTitle, SAspectRatio, SAvatar, SBadge, SButton, SEmpty, SEmptyContent,
  SEmptyDescription, SEmptyHeader, SEmptyMedia, SEmptyTitle, SH1, SH2, SH3, SH4, SBlockquote, SIcon, SInlineCode,
  SItem, SItemActions, SItemContent, SItemDescription, SItemGroup, SItemMedia, SItemTitle, SKbd, SKbdGroup, SLarge,
  SLead, SList, SMuted, SP, SSeparator, SSkeleton, SSmall, SSpinner, SparkTheme, SparkUI
} from '@sparkui/core';
import { DemoBlock, DocHeader, DocSection } from '../shell/DocKit';

const space8: FlexSpaceOptions = { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) };
const space16: FlexSpaceOptions = { main: LengthMetrics.vp(16), cross: LengthMetrics.vp(16) };

// ------------------------------------------------------------------------------------------------ Badge

const BADGE_CODE = `SBadge({ text: 'Badge' })
SBadge({ text: 'Secondary', variant: 'secondary' })
SBadge({ text: 'Destructive', variant: 'destructive' })
SBadge({ text: 'Outline', variant: 'outline' })`;

const BADGE_ICON_CODE = `SBadge({ text: 'Verified', variant: 'secondary', icon: 'circle-check' })
SBadge({ text: '8', variant: 'destructive' })
SBadge({ text: 'Link', variant: 'outline', iconRight: 'arrow-right' })
SBadge({ variant: 'outline' }) {
  SSpinner({ sizing: 12 })
  Text('Syncing').fontSize(12)
}`;

@ComponentV2
export struct BadgeDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column({ space: 16 }) {
      DocHeader({ title: 'Badge', lead: 'Displays a badge or a component that looks like a badge.' })
      DocSection({ title: 'Variants' })
      DemoBlock({ code: BADGE_CODE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: space8 }) {
          SBadge({ text: 'Badge' })
          SBadge({ text: 'Secondary', variant: 'secondary' })
          SBadge({ text: 'Destructive', variant: 'destructive' })
          SBadge({ text: 'Outline', variant: 'outline' })
        }
      }
      DocSection({ title: 'With icons', description: 'Leading / trailing lucide icons, or any content in the slot.' })
      DemoBlock({ code: BADGE_ICON_CODE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center, space: space8 }) {
          SBadge({ text: 'Verified', variant: 'secondary', icon: 'circle-check' })
          SBadge({ text: '8', variant: 'destructive' })
          SBadge({ text: 'Link', variant: 'outline', iconRight: 'arrow-right' })
          SBadge({ variant: 'outline' }) {
            SSpinner({ sizing: 12 })
            Text('Syncing')
              .fontSize(this.theme.text.xs)
              .fontWeight(this.theme.text.weightMedium)
              .fontColor(this.theme.colors.foreground)
          }
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Avatar

const AVATAR_CODE = `SAvatar({ src: $r('app.media.startIcon'), fallback: 'SP' })
SAvatar({ src: 'https://example.invalid/me.png', fallback: 'CN' })  // load error → initials
SAvatar({ fallback: 'JD', sizing: 40 })
SAvatar({ fallback: 'AB', sizing: 56 })`;

const AVATAR_GROUP_CODE = `Row() {
  ForEach(['CN', 'LR', 'ER'], (n: string, i: number) => {
    Stack() { SAvatar({ fallback: n }) }
      .border({ width: 2, color: theme.colors.background, radius: 18 })
      .margin({ left: i === 0 ? 0 : -8 })
  })
}`;

@ComponentV2
export struct AvatarDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  private people: string[] = ['CN', 'LR', 'ER', 'MK'];

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Avatar',
        lead: 'An image element with a fallback for representing the user. The initials show while loading, ' +
          'without a source, and when the image fails to load.'
      })
      DemoBlock({ code: AVATAR_CODE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center, space: space16 }) {
          SAvatar({ src: $r('app.media.startIcon'), fallback: 'SP' })
          SAvatar({ src: 'https://example.invalid/me.png', fallback: 'CN' })
          SAvatar({ fallback: 'JD', sizing: 40 })
          SAvatar({ fallback: 'AB', sizing: 56 })
        }
      }
      DocSection({ title: 'Group', description: 'Overlap avatars with a background-coloured ring.' })
      DemoBlock({ code: AVATAR_GROUP_CODE }) {
        Row() {
          ForEach(this.people, (n: string, i: number) => {
            Stack() {
              SAvatar({ fallback: n })
            }
            .border({ width: 2, color: this.theme.colors.background, radius: 18 })
            .margin({ left: i === 0 ? 0 : -8 })
          }, (n: string) => n)
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Alert

const ALERT_CODE = `SAlert({ icon: 'circle-check' }) {
  SAlertTitle({ text: 'Success! Your changes have been saved' })
  SAlertDescription({ text: 'This is an alert with icon, title and description.' })
}
SAlert({ icon: 'info', heading: 'This Alert has a title and an icon. No description.' })
SAlert({ variant: 'destructive', icon: 'circle-alert' }) {
  SAlertTitle({ text: 'Unable to process your payment.' })
  SAlertDescription({ text: 'Please verify your billing information and try again.' })
}`;

@ComponentV2
export struct AlertDoc {
  build() {
    Column({ space: 16 }) {
      DocHeader({ title: 'Alert', lead: 'Displays a callout for user attention.' })
      DemoBlock({ code: ALERT_CODE }) {
        Column({ space: 16 }) {
          SAlert({ icon: 'circle-check' }) {
            SAlertTitle({ text: 'Success! Your changes have been saved' })
            SAlertDescription({ text: 'This is an alert with icon, title and description.' })
          }
          SAlert({ icon: 'info', heading: 'This Alert has a title and an icon. No description.' })
          SAlert({ variant: 'destructive', icon: 'circle-alert' }) {
            SAlertTitle({ text: 'Unable to process your payment.' })
            SAlertDescription({
              text: 'Please verify your billing information and try again. Check your card details, ensure ' +
                'sufficient funds, and verify your billing address.'
            })
          }
          SAlert({ heading: 'No icon', description: 'Without an icon the text spans the full width.' })
        }
        .width('100%')
        .constraintSize({ maxWidth: 560 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Skeleton + Spinner

const SKELETON_CODE = `Row({ space: 16 }) {
  SSkeleton({ boxWidth: 48, boxHeight: 48, circle: true })
  Column({ space: 8 }) {
    SSkeleton({ boxWidth: 250, boxHeight: 16 })
    SSkeleton({ boxWidth: 200, boxHeight: 16 })
  }
}`;

const SKELETON_CARD_CODE = `Column({ space: 12 }) {
  SSkeleton({ boxWidth: '100%', boxHeight: 125 })   // rounded-xl via modifier if you like
  SSkeleton({ boxWidth: '80%', boxHeight: 16 })
  SSkeleton({ boxWidth: '60%', boxHeight: 16 })
}`;

const SPINNER_CODE = `SSpinner()
SSpinner({ sizing: 24 })
SSpinner({ sizing: 32, color: theme.colors.mutedForeground })
SButton({ text: 'Loading…', loading: true, variant: 'outline' })
SBadge({ variant: 'secondary' }) { SSpinner({ sizing: 12 }); Text('Syncing') }`;

@ComponentV2
export struct SkeletonDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column({ space: 16 }) {
      DocHeader({ title: 'Skeleton', lead: 'Use to show a placeholder while content is loading.' })
      DemoBlock({ code: SKELETON_CODE }) {
        Row({ space: 16 }) {
          SSkeleton({ boxWidth: 48, boxHeight: 48, circle: true })
          Column({ space: 8 }) {
            SSkeleton({ boxWidth: 220, boxHeight: 16 })
            SSkeleton({ boxWidth: 170, boxHeight: 16 })
          }
          .alignItems(HorizontalAlign.Start)
        }
      }
      DocSection({ title: 'Card' })
      DemoBlock({ code: SKELETON_CARD_CODE }) {
        Column({ space: 12 }) {
          SSkeleton({ boxWidth: '100%', boxHeight: 125 })
          SSkeleton({ boxWidth: '80%', boxHeight: 16 })
          SSkeleton({ boxWidth: '60%', boxHeight: 16 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 300 })
      }
      DocHeader({ title: 'Spinner', lead: 'An indicator that can be used to show a loading state.' })
      DemoBlock({ code: SPINNER_CODE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center, space: space16 }) {
          SSpinner()
          SSpinner({ sizing: 24 })
          SSpinner({ sizing: 32, color: this.theme.colors.mutedForeground })
          SButton({ text: 'Loading…', loading: true, variant: 'outline' })
          SBadge({ variant: 'secondary' }) {
            SSpinner({ sizing: 12, color: this.theme.colors.secondaryForeground })
            Text('Syncing')
              .fontSize(this.theme.text.xs)
              .fontWeight(this.theme.text.weightMedium)
              .fontColor(this.theme.colors.secondaryForeground)
          }
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Separator + Kbd

const SEPARATOR_CODE = `Column({ space: 4 }) {
  Text('Radix Primitives')
  Text('An open-source UI component library.')
}
SSeparator()
Row({ space: 16 }) {
  Text('Blog')
  SSeparator({ orientation: 'vertical' })
  Text('Docs')
  SSeparator({ orientation: 'vertical' })
  Text('Source')
}.height(20)`;

const KBD_CODE = `SKbdGroup() {
  SKbd({ icon: 'command' })
  SKbd({ text: '⇧' })
  SKbd({ text: '⌥' })
  SKbd({ text: '⌃' })
}
SKbdGroup() {
  SKbd({ text: 'Ctrl' })
  Text('+')
  SKbd({ text: 'B' })
}
SKbd({ icon: 'corner-down-left' })`;

@ComponentV2
export struct SeparatorDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Column({ space: 16 }) {
      DocHeader({ title: 'Separator', lead: 'Visually or semantically separates content.' })
      DemoBlock({ code: SEPARATOR_CODE }) {
        Column({ space: 16 }) {
          Column({ space: 4 }) {
            Text('Radix Primitives')
              .fontSize(this.theme.text.sm)
              .fontWeight(this.theme.text.weightMedium)
              .fontColor(this.theme.colors.foreground)
            Text('An open-source UI component library.')
              .fontSize(this.theme.text.sm)
              .fontColor(this.theme.colors.mutedForeground)
          }
          .alignItems(HorizontalAlign.Start)
          SSeparator()
          Row({ space: 16 }) {
            Text('Blog').fontSize(this.theme.text.sm).fontColor(this.theme.colors.foreground)
            SSeparator({ orientation: 'vertical' })
            Text('Docs').fontSize(this.theme.text.sm).fontColor(this.theme.colors.foreground)
            SSeparator({ orientation: 'vertical' })
            Text('Source').fontSize(this.theme.text.sm).fontColor(this.theme.colors.foreground)
          }
          .height(20)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .constraintSize({ maxWidth: 320 })
      }
      DocHeader({ title: 'Kbd', lead: 'Used to display textual user input from keyboard.' })
      DemoBlock({ code: KBD_CODE }) {
        Column({ space: 16 }) {
          SKbdGroup() {
            SKbd({ icon: 'command' })
            SKbd({ text: '⇧' })
            SKbd({ text: '⌥' })
            SKbd({ text: '⌃' })
          }
          SKbdGroup() {
            SKbd({ text: 'Ctrl' })
            Text('+').fontSize(this.theme.text.xs).fontColor(this.theme.colors.mutedForeground)
            SKbd({ text: 'B' })
          }
          Row({ space: 6 }) {
            Text('Press').fontSize(this.theme.text.sm).fontColor(this.theme.colors.mutedForeground)
            SKbd({ icon: 'corner-down-left' })
            Text('to send').fontSize(this.theme.text.sm).fontColor(this.theme.colors.mutedForeground)
          }
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Empty

const EMPTY_CODE = `SEmpty({ bordered: true }) {
  SEmptyHeader() {
    SEmptyMedia({ icon: 'folder', variant: 'icon' })
    SEmptyTitle({ text: 'No Projects Yet' })
    SEmptyDescription({ text: "You haven't created any projects yet. Get started by creating your first project." })
  }
  SEmptyContent() {
    Row({ space: 8 }) {
      SButton({ text: 'Create Project' })
      SButton({ text: 'Import Project', variant: 'outline' })
    }
    SButton({ text: 'Learn More', variant: 'link', sizing: 'sm', iconRight: 'arrow-up-right' })
  }
}`;

const EMPTY_AVATAR_CODE = `SEmpty() {
  SEmptyHeader() {
    SEmptyMedia() { SAvatar({ fallback: 'LR', sizing: 48 }) }
    SEmptyTitle({ text: 'User Offline' })
    SEmptyDescription({ text: 'This user is currently offline. You can leave a message.' })
  }
  SEmptyContent() { SButton({ text: 'Leave Message', variant: 'outline', sizing: 'sm' }) }
}`;

@ComponentV2
export struct EmptyDoc {
  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Empty',
        lead: 'Use the Empty component to display an empty state. Padding grows from 24 to 48vp when the ' +
          'component itself is wider than 480vp.'
      })
      DemoBlock({ code: EMPTY_CODE }) {
        SEmpty({ bordered: true }) {
          SEmptyHeader() {
            SEmptyMedia({ icon: 'folder', variant: 'icon' })
            SEmptyTitle({ text: 'No Projects Yet' })
            SEmptyDescription({
              text: 'You haven\'t created any projects yet. Get started by creating your first project.'
            })
          }
          SEmptyContent() {
            Row({ space: 8 }) {
              SButton({ text: 'Create Project' })
              SButton({ text: 'Import Project', variant: 'outline' })
            }
            SButton({ text: 'Learn More', variant: 'link', sizing: 'sm', iconRight: 'external-link' })
          }
        }
      }
      DocSection({ title: 'Avatar media' })
      DemoBlock({ code: EMPTY_AVATAR_CODE }) {
        SEmpty() {
          SEmptyHeader() {
            SEmptyMedia() {
              SAvatar({ fallback: 'LR', sizing: 48 })
            }
            SEmptyTitle({ text: 'User Offline' })
            SEmptyDescription({ text: 'This user is currently offline. You can leave a message to notify them.' })
          }
          SEmptyContent() {
            SButton({ text: 'Leave Message', variant: 'outline', sizing: 'sm' })
          }
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Item

const ITEM_CODE = `SItem({ variant: 'outline' }) {
  SItemContent() {
    SItemTitle({ text: 'Basic Item' })
    SItemDescription({ text: 'A simple item with title and description.' })
  }
  SItemActions() { SButton({ text: 'Action', variant: 'outline', sizing: 'sm' }) }
}
SItem({ variant: 'muted', sizing: 'sm' }) {
  SItemMedia({ icon: 'badge-check' })
  SItemContent() { SItemTitle({ text: 'Your profile has been verified.' }) }
  SItemActions() { SIcon({ name: 'chevron-right', sizing: 16 }) }
}`;

const ITEM_SETTINGS_CODE = `SItemGroup({ bordered: true, separators: true }) {
  Stack() {
    SItem({ interactive: true }) {
      SItemMedia({ icon: 'bell', variant: 'icon', tint: theme.colors.chart1 })
      SItemContent() {
        SItemTitle({ text: 'Notifications' })
        SItemDescription({ text: 'Push, email and in-app alerts.' })
      }
      SItemActions() { SIcon({ name: 'chevron-right', color: theme.colors.mutedForeground }) }
    }
  }.onClick(() => this.open('notifications'))
  SItem() {
    SItemMedia({ icon: 'shield-check', variant: 'icon', tint: theme.colors.chart2 })
    SItemContent() {
      SItemTitle({ text: 'Two-factor authentication' }) { SBadge({ text: 'On', variant: 'secondary' }) }
      SItemDescription({ text: 'Require a code from your phone when signing in.' })
    }
    SItemActions() { SButton({ text: 'Manage', variant: 'outline', sizing: 'sm' }) }
  }
  ...
}`;

const ITEM_MEDIA_CODE = `SItem({ variant: 'outline' }) {
  SItemMedia({ variant: 'image', src: $r('app.media.startIcon') })
  SItemContent() {
    SItemTitle({ text: 'SparkUI Gallery' })
    SItemDescription({ text: 'Version 0.1.0 · HarmonyOS' })
  }
  SItemActions() { SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'download', label: 'Download' }) }
}
SItem({ variant: 'outline' }) {
  SItemMedia() { SAvatar({ fallback: 'ER', sizing: 40 }) }
  SItemContent() {
    SItemTitle({ text: 'Evil Rabbit' })
    SItemDescription({ text: 'Last seen 5 months ago' })
  }
  SItemActions() { SButton({ text: 'Invite', sizing: 'sm', icon: 'plus' }) }
}`;

@ComponentV2
export struct ItemDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local lastTapped: string = '—';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Item',
        lead: 'A versatile row for lists and settings: media, title, description and actions. When an item is ' +
          'narrower than 360vp its actions wrap under the text.'
      })
      DemoBlock({ code: ITEM_CODE }) {
        Column({ space: 16 }) {
          SItem({ variant: 'outline' }) {
            SItemContent() {
              SItemTitle({ text: 'Basic Item' })
              SItemDescription({ text: 'A simple item with title and description.' })
            }
            SItemActions() {
              SButton({ text: 'Action', variant: 'outline', sizing: 'sm' })
            }
          }
          SItem({ variant: 'muted', sizing: 'sm' }) {
            SItemMedia({ icon: 'circle-check' })
            SItemContent() {
              SItemTitle({ text: 'Your profile has been verified.' })
            }
            SItemActions() {
              SIcon({ name: 'chevron-right', sizing: 16, color: this.theme.colors.mutedForeground })
            }
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 520 })
      }

      DocSection({
        title: 'Settings group',
        description: 'SItemGroup({ bordered, separators }) turns rows into a settings card: flush rows, inset ' +
          'hairlines, tinted icon tiles and pressed feedback on interactive rows.'
      })
      DemoBlock({ code: ITEM_SETTINGS_CODE }) {
        Column({ space: 12 }) {
          Text('ACCOUNT')
            .fontSize(this.theme.text.xs)
            .fontWeight(this.theme.text.weightMedium)
            .letterSpacing(0.6)
            .fontColor(this.theme.colors.mutedForeground)
            .padding({ left: 4 })
          SItemGroup({ bordered: true, separators: true }) {
            Stack() {
              SItem({ interactive: true }) {
                SItemMedia({ icon: 'user', variant: 'icon', tint: this.theme.colors.chart1 })
                SItemContent() {
                  SItemTitle({ text: 'Profile' })
                  SItemDescription({ text: 'Name, photo and public information.' })
                }
                SItemActions() {
                  SIcon({ name: 'chevron-right', sizing: 16, color: this.theme.colors.mutedForeground })
                }
              }
            }
            .onClick(() => {
              this.lastTapped = 'Profile';
            })
            Stack() {
              SItem({ interactive: true }) {
                SItemMedia({ icon: 'bell', variant: 'icon', tint: this.theme.colors.chart2 })
                SItemContent() {
                  SItemTitle({ text: 'Notifications' })
                  SItemDescription({ text: 'Push, email and in-app alerts.' })
                }
                SItemActions() {
                  SBadge({ text: '3', variant: 'destructive' })
                  SIcon({ name: 'chevron-right', sizing: 16, color: this.theme.colors.mutedForeground })
                }
              }
            }
            .onClick(() => {
              this.lastTapped = 'Notifications';
            })
            SItem() {
              SItemMedia({ icon: 'shield-check', variant: 'icon', tint: this.theme.colors.chart3 })
              SItemContent() {
                SItemTitle({ text: 'Two-factor authentication' }) {
                  SBadge({ text: 'On', variant: 'secondary' })
                }
                SItemDescription({ text: 'Require a code from your phone when signing in on a new device.' })
              }
              SItemActions() {
                SButton({ text: 'Manage', variant: 'outline', sizing: 'sm' })
              }
            }
            Stack() {
              SItem({ interactive: true }) {
                SItemMedia({ icon: 'palette', variant: 'icon', tint: this.theme.colors.chart4 })
                SItemContent() {
                  SItemTitle({ text: 'Appearance' })
                }
                SItemActions() {
                  Text('System')
                    .fontSize(this.theme.text.sm)
                    .fontColor(this.theme.colors.mutedForeground)
                  SIcon({ name: 'chevron-right', sizing: 16, color: this.theme.colors.mutedForeground })
                }
              }
            }
            .onClick(() => {
              this.lastTapped = 'Appearance';
            })
          }

          Text('DANGER ZONE')
            .fontSize(this.theme.text.xs)
            .fontWeight(this.theme.text.weightMedium)
            .letterSpacing(0.6)
            .fontColor(this.theme.colors.mutedForeground)
            .padding({ left: 4, top: 8 })
          SItemGroup({ bordered: true, separators: true }) {
            SItem() {
              SItemMedia({ icon: 'log-out', variant: 'icon' })
              SItemContent() {
                SItemTitle({ text: 'Sign out everywhere' })
                SItemDescription({ text: 'End all sessions on other devices.' })
              }
              SItemActions() {
                SButton({ text: 'Sign out', variant: 'outline', sizing: 'sm' })
              }
            }
            SItem() {
              SItemMedia({ icon: 'trash', variant: 'icon', tint: this.theme.colors.destructive })
              SItemContent() {
                SItemTitle({ text: 'Delete account' })
                SItemDescription({ text: 'Permanently remove your account and all of its data.' })
              }
              SItemActions() {
                SButton({ text: 'Delete', variant: 'destructive', sizing: 'sm' })
              }
            }
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 560 })
      }
      Text(`last tapped: ${this.lastTapped}`)
        .fontSize(this.theme.text.xs)
        .fontColor(this.theme.colors.mutedForeground)

      DocSection({ title: 'Image & avatar media' })
      DemoBlock({ code: ITEM_MEDIA_CODE }) {
        Column({ space: 16 }) {
          SItem({ variant: 'outline' }) {
            SItemMedia({ variant: 'image', src: $r('app.media.startIcon') })
            SItemContent() {
              SItemTitle({ text: 'SparkUI Gallery' })
              SItemDescription({ text: 'Version 0.1.0 · HarmonyOS' })
            }
            SItemActions() {
              SButton({ variant: 'ghost', sizing: 'icon-sm', icon: 'download', label: 'Download' })
            }
          }
          SItem({ variant: 'outline' }) {
            SItemMedia() {
              SAvatar({ fallback: 'ER', sizing: 40 })
            }
            SItemContent() {
              SItemTitle({ text: 'Evil Rabbit' })
              SItemDescription({ text: 'Last seen 5 months ago' })
            }
            SItemActions() {
              SButton({ text: 'Invite', sizing: 'sm', icon: 'plus' })
            }
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 520 })
      }

      DocSection({ title: 'Narrow', description: 'Below 360vp the actions move to their own line under the text.' })
      DemoBlock({ code: '// same SItem, placed in a 300vp wide column' }) {
        Column() {
          SItem({ variant: 'outline' }) {
            SItemMedia({ icon: 'cloud-upload', variant: 'icon' })
            SItemContent() {
              SItemTitle({ text: 'Automatic backups' })
              SItemDescription({ text: 'Back up photos and documents every night over Wi-Fi.' })
            }
            SItemActions() {
              SButton({ text: 'Configure', variant: 'outline', sizing: 'sm' })
              SButton({ text: 'Back up now', sizing: 'sm' })
            }
          }
        }
        .width(300)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Typography

const TYPO_CODE = `SH1({ text: 'Taxing Laughter: The Joke Tax Chronicles' })
SLead({ text: 'A modal dialog that interrupts the user with important content.' })
SH2({ text: 'The People of the Kingdom' })
SP({ text: 'Once upon a time, in a far-off land, there was a very lazy king…' })
SH3({ text: 'The Joke Tax' })
SH4({ text: 'People stopped telling jokes' })
SBlockquote({ text: '"After all," he said, "everyone enjoys a good joke, so it\\'s only fair that they should pay for the privilege."' })
SList({ items: ['1st level of puns: 5 gold coins', '2nd level of jokes: 10 gold coins'] })
SInlineCode({ text: '@sparkui/core' })
SLarge({ text: 'Are you absolutely sure?' })
SSmall({ text: 'Email address' })
SMuted({ text: 'Enter your email address.' })`;

@ComponentV2
export struct TypographyDoc {
  build() {
    Column({ space: 16 }) {
      DocHeader({ title: 'Typography', lead: 'Styles for headings, paragraphs, lists… as components.' })
      DemoBlock({ code: TYPO_CODE, centered: false }) {
        Column({ space: 20 }) {
          SH1({ text: 'Taxing Laughter: The Joke Tax Chronicles' })
          SLead({ text: 'A modal dialog that interrupts the user with important content and expects a response.' })
          SH2({ text: 'The People of the Kingdom' })
          SP({
            text: 'Once upon a time, in a far-off land, there was a very lazy king who spent all day lounging on ' +
              'his throne. One day, his advisors came to him with a problem: the kingdom was running out of money.'
          })
          SH3({ text: 'The Joke Tax' })
          SH4({ text: 'People stopped telling jokes' })
          SBlockquote({
            text: '"After all," he said, "everyone enjoys a good joke, so it\'s only fair that they should pay for ' +
              'the privilege."'
          })
          SList({
            items: ['1st level of puns: 5 gold coins', '2nd level of jokes: 10 gold coins',
              '3rd level of one-liners: 20 gold coins']
          })
          Row({ space: 8 }) {
            SP({ text: 'Install' })
            SInlineCode({ text: '@sparkui/core' })
          }
          SLarge({ text: 'Are you absolutely sure?' })
          SSmall({ text: 'Email address' })
          SMuted({ text: 'Enter your email address.' })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Aspect Ratio

const ASPECT_CODE = `SAspectRatio({ ratio: 16 / 9 }) {
  Image($r('app.media.background'))
    .width('100%')
    .height('100%')
    .objectFit(ImageFit.Cover)
}`;

@ComponentV2
export struct AspectRatioDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  private ratios: number[] = [16 / 9, 4 / 3, 1];
  private labels: string[] = ['16 : 9', '4 : 3', '1 : 1'];

  build() {
    Column({ space: 16 }) {
      DocHeader({ title: 'Aspect Ratio', lead: 'Displays content within a desired ratio.' })
      DemoBlock({ code: ASPECT_CODE }) {
        Column() {
          SAspectRatio({ ratio: 16 / 9 }) {
            Image($r('app.media.background'))
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 450 })
        .border({ width: 0, radius: this.theme.radiusLg })
        .clip(true)
      }
      DocSection({ title: 'Ratios' })
      DemoBlock({ code: 'SAspectRatio({ ratio: 4 / 3 }) { ... }' }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: space16 }) {
          ForEach(this.ratios, (r: number, i: number) => {
            Column() {
              SAspectRatio({ ratio: r }) {
                Text(this.labels[i])
                  .fontSize(this.theme.text.sm)
                  .fontWeight(this.theme.text.weightMedium)
                  .fontColor(this.theme.colors.mutedForeground)
              }
            }
            .width(140)
            .backgroundColor(this.theme.colors.muted)
            .border({ width: 0, radius: this.theme.radiusMd })
          }, (r: number, i: number) => `${i}`)
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
