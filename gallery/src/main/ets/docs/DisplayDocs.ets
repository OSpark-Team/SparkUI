import { LengthMetrics } from '@kit.ArkUI';
import {
  SAlert, SAlertDescription, SAlertTitle, SAspectRatio, SAvatar, SAvatarGroup, SBadge, SButton, SEmpty, SEmptyContent,
  SEmptyDescription, SEmptyHeader, SEmptyMedia, SEmptyTitle, SH1, SH2, SH3, SH4, SBlockquote, SIcon, SInlineCode,
  SItem, SItemActions, SItemContent, SItemDescription, SItemGroup, SItemMedia, SItemTitle, SKbd, SKbdGroup, SLarge,
  SLead, SList, SMuted, SP, SSeparator, SSkeleton, SSmall, SSpinner, SparkTheme, SparkUI
} from '@ospark/sparkui';
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

const BADGE_TONES_CODE = `SBadge({ text: 'Success', variant: 'success' })
SBadge({ text: 'Warning', variant: 'warning' })
SBadge({ text: 'Info', variant: 'info' })
// soft: tinted background, coloured text
SBadge({ text: 'Default', soft: true })
SBadge({ text: 'Success', variant: 'success', soft: true })
SBadge({ text: 'Warning', variant: 'warning', soft: true })
SBadge({ text: 'Info', variant: 'info', soft: true })
SBadge({ text: 'Destructive', variant: 'destructive', soft: true })`;

const BADGE_SIZES_CODE = `SBadge({ text: 'Small', sizing: 'sm' })
SBadge({ text: 'Default' })
SBadge({ text: 'Large', sizing: 'lg' })
SBadge({ text: 'Pill', pill: true, variant: 'secondary' })
SBadge({ text: 'Large pill', pill: true, sizing: 'lg', variant: 'outline', icon: 'star' })`;

const BADGE_STATUS_CODE = `SBadge({ text: 'Online', variant: 'success', soft: true, dot: true, pill: true })
SBadge({ text: 'Away', variant: 'warning', soft: true, dot: true, pill: true })
SBadge({ text: 'Offline', variant: 'outline', dot: true, dotColor: theme.colors.mutedForeground, pill: true })
SBadge({ dot: true, variant: 'destructive' })      // bare 8vp dot
SBadge({ count: 8, variant: 'destructive' })
SBadge({ count: 128, variant: 'destructive' })      // "99+"
SBadge({ count: 1200, max: 999 })                   // "999+"
// over an icon
Stack({ alignContent: Alignment.TopEnd }) {
  SIcon({ name: 'bell', sizing: 24 })
  SBadge({ count: 3, variant: 'destructive', sizing: 'sm' }).translate({ x: 8, y: -6 })
}`;

const BADGE_REMOVABLE_CODE = `@Local tags: string[] = ['react', 'vue', 'svelte', 'arkts'];

ForEach(this.tags, (t: string) => {
  SBadge({ text: t, variant: 'secondary', removable: true,
    onRemove: () => this.tags = this.tags.filter((x: string) => x !== t) })
}, (t: string) => t)`;

const INITIAL_TAGS: string[] = ['react', 'vue', 'svelte', 'arkts', 'solid'];

@ComponentV2
export struct BadgeDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local tags: string[] = INITIAL_TAGS.slice();

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
      DocSection({ title: 'Status tones', description: "success | warning | info, solid or soft (tinted)." })
      DemoBlock({ code: BADGE_TONES_CODE }) {
        Column({ space: 12 }) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: space8 }) {
            SBadge({ text: 'Success', variant: 'success' })
            SBadge({ text: 'Warning', variant: 'warning' })
            SBadge({ text: 'Info', variant: 'info' })
          }
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: space8 }) {
            SBadge({ text: 'Default', soft: true })
            SBadge({ text: 'Success', variant: 'success', soft: true })
            SBadge({ text: 'Warning', variant: 'warning', soft: true })
            SBadge({ text: 'Info', variant: 'info', soft: true })
            SBadge({ text: 'Destructive', variant: 'destructive', soft: true })
          }
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
      DocSection({ title: 'Sizes & shapes', description: "sizing: 'sm' | 'default' | 'lg'; pill: rounded-full." })
      DemoBlock({ code: BADGE_SIZES_CODE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center, space: space8 }) {
          SBadge({ text: 'Small', sizing: 'sm' })
          SBadge({ text: 'Default' })
          SBadge({ text: 'Large', sizing: 'lg' })
          SBadge({ text: 'Pill', pill: true, variant: 'secondary' })
          SBadge({ text: 'Large pill', pill: true, sizing: 'lg', variant: 'outline', icon: 'star' })
        }
      }
      DocSection({ title: 'Dot & count', description: 'Status dots, bare dots and notification counts with a max.' })
      DemoBlock({ code: BADGE_STATUS_CODE }) {
        Column({ space: 16 }) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center, space: space8 }) {
            SBadge({ text: 'Online', variant: 'success', soft: true, dot: true, pill: true })
            SBadge({ text: 'Away', variant: 'warning', soft: true, dot: true, pill: true })
            SBadge({
              text: 'Offline',
              variant: 'outline',
              dot: true,
              dotColor: this.theme.colors.mutedForeground,
              pill: true
            })
            SBadge({ dot: true, variant: 'destructive' })
          }
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center, space: space16 }) {
            SBadge({ count: 8, variant: 'destructive' })
            SBadge({ count: 128, variant: 'destructive' })
            SBadge({ count: 1200, max: 999 })
            Stack({ alignContent: Alignment.TopEnd }) {
              SIcon({ name: 'bell', sizing: 24, color: this.theme.colors.foreground })
              SBadge({ count: 3, variant: 'destructive', sizing: 'sm' })
                .translate({ x: 8, y: -6 })
            }
            Stack({ alignContent: Alignment.TopEnd }) {
              SIcon({ name: 'mail', sizing: 24, color: this.theme.colors.foreground })
              SBadge({ dot: true, variant: 'destructive' })
                .translate({ x: 2, y: -1 })
            }
          }
        }
      }
      DocSection({ title: 'Removable', description: 'removable adds a × that emits onRemove (tags, filters).' })
      DemoBlock({ code: BADGE_REMOVABLE_CODE }) {
        Column({ space: 12 }) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: space8 }) {
            ForEach(this.tags, (t: string) => {
              SBadge({
                text: t,
                variant: 'secondary',
                removable: true,
                onRemove: () => {
                  this.tags = this.tags.filter((x: string) => x !== t);
                }
              })
            }, (t: string) => t)
          }
          if (this.tags.length < INITIAL_TAGS.length) {
            SButton({ text: 'Reset', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.tags = INITIAL_TAGS.slice();
            })
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

const AVATAR_SIZES_CODE = `SAvatar({ fallback: 'XS', sizing: 'xs' })
SAvatar({ fallback: 'SM', sizing: 'sm' })
SAvatar({ fallback: 'DF' })
SAvatar({ fallback: 'MD', sizing: 'md' })
SAvatar({ fallback: 'LG', sizing: 'lg' })
SAvatar({ fallback: 'XL', sizing: 'xl' })`;

const AVATAR_SHAPES_CODE = `SAvatar({ src: $r('app.media.startIcon'), fallback: 'SP', sizing: 'lg' })
SAvatar({ src: $r('app.media.startIcon'), fallback: 'SP', sizing: 'lg', shape: 'rounded' })
SAvatar({ src: $r('app.media.startIcon'), fallback: 'SP', sizing: 'lg', shape: 'square' })
SAvatar({ fallback: 'ON', sizing: 'lg', status: 'online' })
SAvatar({ fallback: 'AW', sizing: 'lg', status: 'away' })
SAvatar({ fallback: 'BS', sizing: 'lg', status: 'busy', shape: 'rounded' })
SAvatar({ fallback: 'OF', sizing: 'lg', status: 'offline' })`;

const AVATAR_GROUP_CODE = `SAvatarGroup({ fallbacks: ['CN', 'LR', 'ER', 'MK'] })
SAvatarGroup({ fallbacks: ['CN', 'LR', 'ER', 'MK', 'JD', 'AB'], max: 3, sizing: 'md' })
SAvatarGroup({ fallbacks: ['SP', 'CN'], sources: [$r('app.media.startIcon')], extra: 12,
  sizing: 'lg', shape: 'rounded' })`;

@ComponentV2
export struct AvatarDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

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
      DocSection({ title: 'Sizes', description: "sizing: vp, or 'xs' | 'sm' | 'default' | 'md' | 'lg' | 'xl'." })
      DemoBlock({ code: AVATAR_SIZES_CODE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center, space: space16 }) {
          SAvatar({ fallback: 'XS', sizing: 'xs' })
          SAvatar({ fallback: 'SM', sizing: 'sm' })
          SAvatar({ fallback: 'DF' })
          SAvatar({ fallback: 'MD', sizing: 'md' })
          SAvatar({ fallback: 'LG', sizing: 'lg' })
          SAvatar({ fallback: 'XL', sizing: 'xl' })
        }
      }
      DocSection({ title: 'Shapes & status', description: "shape: circle | rounded | square; status: online | away | busy | offline." })
      DemoBlock({ code: AVATAR_SHAPES_CODE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center, space: space16 }) {
          SAvatar({ src: $r('app.media.startIcon'), fallback: 'SP', sizing: 'lg' })
          SAvatar({ src: $r('app.media.startIcon'), fallback: 'SP', sizing: 'lg', shape: 'rounded' })
          SAvatar({ src: $r('app.media.startIcon'), fallback: 'SP', sizing: 'lg', shape: 'square' })
          SAvatar({ fallback: 'ON', sizing: 'lg', status: 'online' })
          SAvatar({ fallback: 'AW', sizing: 'lg', status: 'away' })
          SAvatar({ fallback: 'BS', sizing: 'lg', status: 'busy', shape: 'rounded' })
          SAvatar({ fallback: 'OF', sizing: 'lg', status: 'offline' })
        }
      }
      DocSection({ title: 'Group', description: 'SAvatarGroup overlaps avatars with a background ring and adds "+N".' })
      DemoBlock({ code: AVATAR_GROUP_CODE }) {
        Column({ space: 16 }) {
          SAvatarGroup({ fallbacks: ['CN', 'LR', 'ER', 'MK'] })
          SAvatarGroup({ fallbacks: ['CN', 'LR', 'ER', 'MK', 'JD', 'AB'], max: 3, sizing: 'md' })
          SAvatarGroup({
            fallbacks: ['SP', 'CN'],
            sources: [$r('app.media.startIcon')],
            extra: 12,
            sizing: 'lg',
            shape: 'rounded'
          })
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

const ALERT_TONES_CODE = `SAlert({ variant: 'success', icon: 'circle-check', heading: 'Deployment finished',
  description: 'Your site is live at sparkui.dev.' })
SAlert({ variant: 'warning', icon: 'triangle-alert', heading: 'Your trial ends in 3 days' })
SAlert({ variant: 'info', icon: 'info', heading: 'A new version is available' })
// soft: tinted surface and border
SAlert({ variant: 'success', soft: true, icon: 'circle-check', heading: 'Payment received' })
SAlert({ variant: 'warning', soft: true, icon: 'triangle-alert', heading: 'Storage almost full',
  description: '9.2 GB of 10 GB used.' })
SAlert({ variant: 'destructive', soft: true, icon: 'circle-alert', heading: 'Build failed' })`;

const ALERT_ACTIONS_CODE = `SAlert({ variant: 'info', icon: 'info', heading: 'Update available',
  description: 'Version 2.0 brings charts and blocks.', actionLabel: 'Update',
  onAction: () => ..., dismissible: true, onDismiss: () => ... })
SAlert({ variant: 'warning', soft: true, compact: true, icon: 'triangle-alert',
  heading: 'Unsaved changes', actionLabel: 'Save' })
SAlert({ compact: true, icon: 'bell', heading: 'Notifications are muted', dismissible: true })`;

@ComponentV2
export struct AlertDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local round: number = 0;
  @Local events: string = '';

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
      DocSection({ title: 'Status variants', description: 'success | warning | info (+ destructive), plain or soft.' })
      DemoBlock({ code: ALERT_TONES_CODE }) {
        Column({ space: 12 }) {
          SAlert({
            variant: 'success',
            icon: 'circle-check',
            heading: 'Deployment finished',
            description: 'Your site is live at sparkui.dev.'
          })
          SAlert({ variant: 'warning', icon: 'triangle-alert', heading: 'Your trial ends in 3 days' })
          SAlert({ variant: 'info', icon: 'info', heading: 'A new version is available' })
          SAlert({ variant: 'success', soft: true, icon: 'circle-check', heading: 'Payment received' })
          SAlert({
            variant: 'warning',
            soft: true,
            icon: 'triangle-alert',
            heading: 'Storage almost full',
            description: '9.2 GB of 10 GB used.'
          })
          SAlert({ variant: 'destructive', soft: true, icon: 'circle-alert', heading: 'Build failed' })
        }
        .width('100%')
        .constraintSize({ maxWidth: 560 })
      }
      DocSection({
        title: 'Actions, dismissible, compact',
        description: 'A dismissed alert hides itself with the alert motion and emits onDismiss.'
      })
      DemoBlock({ code: ALERT_ACTIONS_CODE }) {
        Column({ space: 12 }) {
          // re-created by `round` so the dismissed alerts can come back
          ForEach([this.round], (r: number) => {
            Column({ space: 12 }) {
              SAlert({
                variant: 'info',
                icon: 'info',
                heading: 'Update available',
                description: 'Version 2.0 brings charts and layout blocks.',
                actionLabel: 'Update',
                onAction: () => {
                  this.events = 'update tapped';
                },
                dismissible: true,
                onDismiss: () => {
                  this.events = 'dismissed';
                }
              })
              SAlert({
                variant: 'warning',
                soft: true,
                compact: true,
                icon: 'triangle-alert',
                heading: 'Unsaved changes',
                actionLabel: 'Save',
                onAction: () => {
                  this.events = 'save tapped';
                }
              })
              SAlert({ compact: true, icon: 'bell', heading: 'Notifications are muted', dismissible: true })
            }
            .width('100%')
          }, (r: number) => `${r}`)
          Row({ space: 8 }) {
            SButton({ text: 'Reset', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.round++;
              this.events = '';
            })
            Text(this.events)
              .fontSize(this.theme.text.xs)
              .fontColor(this.theme.colors.mutedForeground)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
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

const SKELETON_MOTION_CODE = `SSkeleton({ boxWidth: '100%', boxHeight: 16 })                     // pulse
SSkeleton({ boxWidth: '100%', boxHeight: 16, motion: 'shimmer' })
SSkeleton({ boxWidth: '100%', boxHeight: 16, motion: 'none' })`;

const SKELETON_PRESETS_CODE = `SSkeleton({ lines: 3 })                       // paragraph, last line shorter
SSkeleton({ preset: 'list', motion: 'shimmer' })
SSkeleton({ preset: 'card', motion: 'shimmer' })`;

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
      DocSection({ title: 'Motion', description: "motion: 'pulse' (default) | 'shimmer' | 'none'." })
      DemoBlock({ code: SKELETON_MOTION_CODE }) {
        Column({ space: 12 }) {
          SSkeleton({ boxWidth: '100%', boxHeight: 16 })
          SSkeleton({ boxWidth: '100%', boxHeight: 16, motion: 'shimmer' })
          SSkeleton({ boxWidth: '100%', boxHeight: 16, motion: 'none' })
        }
        .width('100%')
        .constraintSize({ maxWidth: 300 })
      }
      DocSection({ title: 'Lines & presets', description: "lines: N; preset: 'text' | 'list' | 'card'." })
      DemoBlock({ code: SKELETON_PRESETS_CODE }) {
        Column({ space: 24 }) {
          SSkeleton({ lines: 3 })
          SSkeleton({ preset: 'list', motion: 'shimmer' })
          SSkeleton({ preset: 'card', motion: 'shimmer' })
        }
        .width('100%')
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

const SEPARATOR_LABEL_CODE = `SSeparator({ label: 'OR CONTINUE WITH' })
SSeparator({ label: 'Today', labelAlignment: 'start' })
SSeparator({ label: 'End of results', labelAlignment: 'end', lineStyle: 'dashed' })
SSeparator({ lineStyle: 'dashed' })
SSeparator({ lineStyle: 'dotted', thickness: 2 })`;

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

const KBD_VARIANTS_CODE = `SKbd({ text: 'Esc', sizing: 'sm' })
SKbd({ text: 'Esc' })
SKbd({ text: 'Esc', sizing: 'lg' })
SKbd({ text: 'Esc', variant: 'outline', sizing: 'lg' })
// combos from strings; cmd / enter / arrows become icons
SKbdGroup({ keys: ['Ctrl', 'Shift', 'P'], separator: '+' })
SKbdGroup({ keys: ['cmd', 'K'], variant: 'outline' })
SKbdGroup({ keys: ['G', 'H'], separator: 'then' })
SKbdGroup({ keys: ['up', 'down', 'enter'], sizing: 'sm' })`;

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
      DocSection({
        title: 'Label & line style',
        description: "label with labelAlignment start | center | end; lineStyle solid | dashed | dotted; thickness."
      })
      DemoBlock({ code: SEPARATOR_LABEL_CODE }) {
        Column({ space: 20 }) {
          SSeparator({ label: 'OR CONTINUE WITH' })
          SSeparator({ label: 'Today', labelAlignment: 'start' })
          SSeparator({ label: 'End of results', labelAlignment: 'end', lineStyle: 'dashed' })
          SSeparator({ lineStyle: 'dashed' })
          SSeparator({ lineStyle: 'dotted', thickness: 2 })
        }
        .width('100%')
        .constraintSize({ maxWidth: 360 })
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
      DocSection({ title: 'Sizes, keycap, combos', description: "sizing sm | default | lg; variant 'outline'; SKbdGroup({ keys })." })
      DemoBlock({ code: KBD_VARIANTS_CODE }) {
        Column({ space: 16 }) {
          Row({ space: 8 }) {
            SKbd({ text: 'Esc', sizing: 'sm' })
            SKbd({ text: 'Esc' })
            SKbd({ text: 'Esc', sizing: 'lg' })
            SKbd({ text: 'Esc', variant: 'outline', sizing: 'lg' })
          }
          .alignItems(VerticalAlign.Center)
          SKbdGroup({ keys: ['Ctrl', 'Shift', 'P'], separator: '+' })
          SKbdGroup({ keys: ['cmd', 'K'], variant: 'outline' })
          SKbdGroup({ keys: ['G', 'H'], separator: 'then' })
          SKbdGroup({ keys: ['up', 'down', 'enter'], sizing: 'sm' })
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

const EMPTY_FILLED_CODE = `SEmpty({ filled: true }) {
  SEmptyHeader() {
    SEmptyMedia({ icon: 'bell', variant: 'icon' })
    SEmptyTitle({ text: 'No Notifications' })
    SEmptyDescription({ text: "You're all caught up." })
  }
}
SEmpty({ compact: true, bordered: true }) {
  SEmptyHeader() {
    SEmptyTitle({ text: 'No results' })
    SEmptyDescription({ text: 'Try a different search.' })
  }
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
      DocSection({ title: 'Filled & compact', description: 'filled: bg-muted/50 surface; compact: 16vp padding for small containers.' })
      DemoBlock({ code: EMPTY_FILLED_CODE }) {
        Column({ space: 16 }) {
          SEmpty({ filled: true }) {
            SEmptyHeader() {
              SEmptyMedia({ icon: 'bell', variant: 'icon' })
              SEmptyTitle({ text: 'No Notifications' })
              SEmptyDescription({ text: 'You\'re all caught up. New notifications will appear here.' })
            }
          }
          SEmpty({ compact: true, bordered: true }) {
            SEmptyHeader() {
              SEmptyTitle({ text: 'No results' })
              SEmptyDescription({ text: 'Try a different search.' })
            }
          }
        }
        .width('100%')
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
SInlineCode({ text: '@ospark/sparkui' })
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
            SInlineCode({ text: '@ospark/sparkui' })
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
