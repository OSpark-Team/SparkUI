import { LengthMetrics } from '@kit.ArkUI';
import {
  SAccordion, SAccordionContent, SAccordionItem, SAccordionTrigger, SBreadcrumb, SBreadcrumbEllipsis, SBreadcrumbItem,
  SBreadcrumbLink, SBreadcrumbList, SBreadcrumbPage, SBreadcrumbSeparator, SButton, SButtonGroup,
  SButtonGroupSeparator, SCollapsible, SCollapsibleContent, SCollapsibleTrigger, SPagination, SScrollArea, STabs,
  STabsContent, STabsList, STabsTrigger, SToggle, SToggleGroup, SToggleGroupItem, SparkTheme, SparkUI
} from '@sparkui/core';
import { DemoBlock, DocHeader, DocSection } from '../shell/DocKit';

const space8: FlexSpaceOptions = { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) };

/** Small "bound value" readout under controlled demos. */
@ComponentV2
struct ValueNote {
  @Param text: string = '';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.xs)
      .fontColor(this.theme.colors.mutedForeground)
  }
}

/** Plain paragraph used inside demos. */
@ComponentV2
struct DemoText {
  @Param text: string = '';
  @Param muted: boolean = false;
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;

  build() {
    Text(this.text)
      .fontSize(this.theme.text.sm)
      .lineHeight(this.theme.text.leadingSm)
      .fontColor(this.muted ? this.theme.colors.mutedForeground : this.theme.colors.foreground)
  }
}

// ------------------------------------------------------------------------------------------------ Tabs

const TABS_CODE = `STabs({ defaultValue: 'account' }) {
  STabsList() {
    STabsTrigger({ value: 'account', text: 'Account' })
    STabsTrigger({ value: 'password', text: 'Password' })
  }
  STabsContent({ value: 'account' }) {
    Text('Make changes to your account here.')
  }
  STabsContent({ value: 'password' }) {
    Text('Change your password here.')
  }
}`;

const TABS_CONTROLLED = `@Local tab: string = 'music';

STabs({ value: this.tab!! }) {
  STabsList() {
    STabsTrigger({ value: 'music', icon: 'music', text: 'Music' })
    STabsTrigger({ value: 'podcasts', icon: 'mic', text: 'Podcasts' })
    STabsTrigger({ value: 'live', text: 'Live', disabled: true })
  }
  STabsContent({ value: 'music' }) { ... }
  STabsContent({ value: 'podcasts' }) { ... }
}
SButton({ text: 'Show podcasts' }).onClick(() => this.tab = 'podcasts')`;

const TABS_OVERFLOW = `// the list scrolls horizontally when it does not fit
Column() {
  STabs({ defaultValue: 'overview' }) {
    STabsList() {
      STabsTrigger({ value: 'overview', text: 'Overview' })
      STabsTrigger({ value: 'analytics', text: 'Analytics' })
      STabsTrigger({ value: 'reports', text: 'Reports' })
      STabsTrigger({ value: 'notifications', text: 'Notifications' })
      STabsTrigger({ value: 'settings', text: 'Settings' })
    }
  }
}
.constraintSize({ maxWidth: 280 })`;

@ComponentV2
export struct TabsDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local tab: string = 'music';
  @Local changes: number = 0;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Tabs',
        lead: 'A set of layered sections of content, known as tab panels, that are displayed one at a time.'
      })
      DemoBlock({ code: TABS_CODE, centered: false }) {
        Column() {
          STabs({ defaultValue: 'account', onValueChange: () => {
            this.changes++;
          } }) {
            STabsList() {
              STabsTrigger({ value: 'account', text: 'Account' })
              STabsTrigger({ value: 'password', text: 'Password' })
            }
            STabsContent({ value: 'account' }) {
              DemoText({ text: 'Make changes to your account here. Click save when you are done.' })
            }
            STabsContent({ value: 'password' }) {
              DemoText({ text: 'Change your password here. After saving, you will be logged out.' })
            }
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 400 })
      }
      ValueNote({ text: `onValueChange fired ${this.changes} times` })

      DocSection({ title: 'Controlled', description: 'Bind the active tab with !! like v-model. Icons and ' +
        'disabled triggers are supported.' })
      DemoBlock({ code: TABS_CONTROLLED, centered: false }) {
        Column({ space: 12 }) {
          STabs({ value: this.tab!! }) {
            STabsList() {
              STabsTrigger({ value: 'music', icon: 'music', text: 'Music' })
              STabsTrigger({ value: 'podcasts', icon: 'mic', text: 'Podcasts' })
              STabsTrigger({ value: 'live', text: 'Live', disabled: true })
            }
            STabsContent({ value: 'music' }) {
              DemoText({ text: 'Top picks for you. Updated daily.', muted: true })
            }
            STabsContent({ value: 'podcasts' }) {
              DemoText({ text: 'Your favorite podcasts. Updated daily.', muted: true })
            }
          }
          Row({ space: 8 }) {
            SButton({ text: 'Show music', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.tab = 'music';
            })
            SButton({ text: 'Show podcasts', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.tab = 'podcasts';
            })
          }
          ValueNote({ text: `tab = '${this.tab}'` })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }

      DocSection({ title: 'Overflow', description: 'Without breakpoints: when the triggers are wider than the ' +
        'space the list gets, it scrolls horizontally.' })
      DemoBlock({ code: TABS_OVERFLOW, centered: false }) {
        Column() {
          STabs({ defaultValue: 'overview' }) {
            STabsList() {
              STabsTrigger({ value: 'overview', text: 'Overview' })
              STabsTrigger({ value: 'analytics', text: 'Analytics' })
              STabsTrigger({ value: 'reports', text: 'Reports' })
              STabsTrigger({ value: 'notifications', text: 'Notifications' })
              STabsTrigger({ value: 'settings', text: 'Settings' })
            }
            STabsContent({ value: 'overview' }) {
              DemoText({ text: 'Overview panel', muted: true })
            }
            STabsContent({ value: 'analytics' }) {
              DemoText({ text: 'Analytics panel', muted: true })
            }
            STabsContent({ value: 'reports' }) {
              DemoText({ text: 'Reports panel', muted: true })
            }
            STabsContent({ value: 'notifications' }) {
              DemoText({ text: 'Notifications panel', muted: true })
            }
            STabsContent({ value: 'settings' }) {
              DemoText({ text: 'Settings panel', muted: true })
            }
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 280 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Accordion

const ACCORDION_CODE = `SAccordion({ type: 'single', collapsible: true, defaultValue: ['item-1'] }) {
  SAccordionItem({ value: 'item-1' }) {
    SAccordionTrigger({ text: 'Is it accessible?' })
    SAccordionContent() { Text('Yes. It adheres to the WAI-ARIA design pattern.') }
  }
  SAccordionItem({ value: 'item-2' }) {
    SAccordionTrigger({ text: 'Is it styled?' })
    SAccordionContent() { Text('Yes. It comes with default styles that match the other components.') }
  }
  SAccordionItem({ value: 'item-3' }) {
    SAccordionTrigger({ text: 'Is it animated?' })
    SAccordionContent() { Text('Yes. It is animated by default.') }
  }
}`;

const ACCORDION_CONTROLLED = `@Local open: string[] = ['shipping'];

SAccordion({ type: 'multiple', value: this.open!! }) {
  SAccordionItem({ value: 'shipping' }) { ... }
  SAccordionItem({ value: 'returns' }) { ... }
  SAccordionItem({ value: 'support', disabled: true }) { ... }
}`;

@ComponentV2
export struct AccordionDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local open: string[] = ['shipping'];

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Accordion',
        lead: 'A vertically stacked set of interactive headings that each reveal a section of content.'
      })
      DemoBlock({ code: ACCORDION_CODE, centered: false }) {
        Column() {
          SAccordion({ type: 'single', collapsible: true, defaultValue: ['item-1'] }) {
            SAccordionItem({ value: 'item-1' }) {
              SAccordionTrigger({ text: 'Is it accessible?' })
              SAccordionContent() {
                DemoText({ text: 'Yes. It adheres to the WAI-ARIA design pattern.' })
              }
            }
            SAccordionItem({ value: 'item-2' }) {
              SAccordionTrigger({ text: 'Is it styled?' })
              SAccordionContent() {
                DemoText({ text: 'Yes. It comes with default styles that match the other components\' aesthetic.' })
              }
            }
            SAccordionItem({ value: 'item-3' }) {
              SAccordionTrigger({ text: 'Is it animated?' })
              SAccordionContent() {
                DemoText({ text: 'Yes. It is animated by default, and the height follows the content.' })
              }
            }
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 480 })
      }

      DocSection({ title: 'Multiple & controlled', description: 'type: \'multiple\' keeps several items open. ' +
        'Bind the open items with !!.' })
      DemoBlock({ code: ACCORDION_CONTROLLED, centered: false }) {
        Column({ space: 12 }) {
          SAccordion({ type: 'multiple', value: this.open!! }) {
            SAccordionItem({ value: 'shipping' }) {
              SAccordionTrigger({ text: 'What are your shipping options?' })
              SAccordionContent() {
                DemoText({ text: 'Standard (5-7 days), express (2-3 days) and overnight delivery.' })
                DemoText({ text: 'All orders are tracked.', muted: true })
              }
            }
            SAccordionItem({ value: 'returns' }) {
              SAccordionTrigger({ text: 'What is your return policy?' })
              SAccordionContent() {
                DemoText({ text: 'Returns are accepted within 30 days of delivery.' })
              }
            }
            SAccordionItem({ value: 'support', disabled: true }) {
              SAccordionTrigger({ text: 'Live support (disabled)' })
              SAccordionContent() {
                DemoText({ text: 'Unavailable.' })
              }
            }
          }
          Row({ space: 8 }) {
            SButton({ text: 'Open all', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.open = ['shipping', 'returns'];
            })
            SButton({ text: 'Close all', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.open = [];
            })
          }
          ValueNote({ text: `open = [${this.open.join(', ')}]` })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .constraintSize({ maxWidth: 480 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Collapsible

const COLLAPSIBLE_CODE = `SCollapsible() {
  Row() {
    Text('@peduarte starred 3 repositories').layoutWeight(1)
    SCollapsibleTrigger() {
      SButton({ variant: 'ghost', sizing: 'icon', icon: 'chevrons-up-down', label: 'Toggle' })
    }
  }
  Text('@radix-ui/primitives')            // always visible
  SCollapsibleContent() {
    Text('@radix-ui/colors')
    Text('@stitches/react')
  }
}`;

const COLLAPSIBLE_CONTROLLED = `@Local open: boolean = false;

SButton({ text: 'Toggle details' }).onClick(() => this.open = !this.open)
SCollapsible({ open: this.open!! }) { ... }`;

@ComponentV2
export struct CollapsibleDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local open: boolean = false;

  @Builder
  repo(name: string) {
    Text(name)
      .fontSize(this.theme.text.sm)
      .fontFamily('monospace')
      .fontColor(this.theme.colors.foreground)
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusMd })
  }

  build() {
    Column({ space: 16 }) {
      DocHeader({ title: 'Collapsible', lead: 'An interactive component which expands/collapses a panel.' })
      DemoBlock({ code: COLLAPSIBLE_CODE }) {
        Column() {
          SCollapsible() {
            Column({ space: 8 }) {
              Row({ space: 16 }) {
                Text('@peduarte starred 3 repositories')
                  .fontSize(this.theme.text.sm)
                  .fontWeight(this.theme.text.weightSemibold)
                  .fontColor(this.theme.colors.foreground)
                  .layoutWeight(1)
                SCollapsibleTrigger() {
                  SButton({ variant: 'ghost', sizing: 'icon', icon: 'chevrons-up-down', label: 'Toggle' })
                }
              }
              .width('100%')
              .padding({ left: 16 })
              this.repo('@radix-ui/primitives')
              SCollapsibleContent() {
                this.repo('@radix-ui/colors')
                this.repo('@stitches/react')
              }
            }
            .width('100%')
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 350 })
      }

      DocSection({ title: 'Controlled', description: 'Bind open with !! like v-model:open.' })
      DemoBlock({ code: COLLAPSIBLE_CONTROLLED }) {
        Column({ space: 12 }) {
          SButton({ text: this.open ? 'Hide details' : 'Show details', variant: 'outline',
            iconRight: this.open ? 'chevron-up' : 'chevron-down' })
            .onClick(() => {
              this.open = !this.open;
            })
          SCollapsible({ open: this.open!! }) {
            SCollapsibleContent() {
              DemoText({ text: 'Order #3102 — 2 items, shipped with express delivery.' })
              DemoText({ text: 'Expected on Thursday.', muted: true })
            }
          }
          ValueNote({ text: `open = ${this.open}` })
        }
        .width('100%')
        .constraintSize({ maxWidth: 350 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Toggle

const TOGGLE_CODE = `SToggle({ icon: 'bold', label: 'Toggle bold' })
SToggle({ variant: 'outline', icon: 'italic', label: 'Toggle italic' })
SToggle({ icon: 'underline', text: 'Underline', defaultPressed: true })
SToggle({ sizing: 'sm', icon: 'bold', label: 'Small' })
SToggle({ sizing: 'lg', icon: 'bold', label: 'Large' })
SToggle({ icon: 'bold', label: 'Disabled', disabled: true })`;

const TOGGLE_CONTROLLED = `@Local bold: boolean = true;

SToggle({ pressed: this.bold!!, variant: 'outline', icon: 'bold', text: 'Bold' })`;

const TOGGLE_GROUP_CODE = `SToggleGroup({ type: 'multiple', variant: 'outline' }) {
  SToggleGroupItem({ value: 'bold', icon: 'bold', label: 'Toggle bold' })
  SToggleGroupItem({ value: 'italic', icon: 'italic', label: 'Toggle italic' })
  SToggleGroupItem({ value: 'underline', icon: 'underline', label: 'Toggle underline' })
}
SToggleGroup({ type: 'single', sizing: 'sm' }) { ... }`;

const TOGGLE_GROUP_CONTROLLED = `@Local alignValue: string[] = ['left'];

SToggleGroup({ type: 'single', variant: 'outline', value: this.alignValue!! }) {
  SToggleGroupItem({ value: 'left', text: 'Left' })
  SToggleGroupItem({ value: 'center', text: 'Center' })
  SToggleGroupItem({ value: 'right', text: 'Right' })
}`;

@ComponentV2
export struct ToggleDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local bold: boolean = true;
  @Local alignValue: string[] = ['left'];
  @Local marks: string[] = [];

  build() {
    Column({ space: 16 }) {
      DocHeader({ title: 'Toggle', lead: 'A two-state button that can be either on or off.' })
      DemoBlock({ code: TOGGLE_CODE }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center, space: space8 }) {
          SToggle({ icon: 'bold', label: 'Toggle bold' })
          SToggle({ variant: 'outline', icon: 'italic', label: 'Toggle italic' })
          SToggle({ icon: 'underline', text: 'Underline', defaultPressed: true })
          SToggle({ sizing: 'sm', icon: 'bold', label: 'Small' })
          SToggle({ sizing: 'lg', icon: 'bold', label: 'Large' })
          SToggle({ icon: 'bold', label: 'Disabled', disabled: true })
        }
      }

      DocSection({ title: 'Controlled', description: 'Bind pressed with !! like v-model:pressed.' })
      DemoBlock({ code: TOGGLE_CONTROLLED }) {
        Column({ space: 12 }) {
          SToggle({ pressed: this.bold!!, variant: 'outline', icon: 'bold', text: 'Bold' })
          ValueNote({ text: `pressed = ${this.bold}` })
        }
      }

      DocSection({ title: 'Toggle Group', description: 'A set of two-state buttons joined into one control. ' +
        'value is a string array for both single and multiple groups.' })
      DemoBlock({ code: TOGGLE_GROUP_CODE }) {
        Column({ space: 16 }) {
          SToggleGroup({ type: 'multiple', variant: 'outline', value: this.marks!! }) {
            SToggleGroupItem({ value: 'bold', icon: 'bold', label: 'Toggle bold' })
            SToggleGroupItem({ value: 'italic', icon: 'italic', label: 'Toggle italic' })
            SToggleGroupItem({ value: 'underline', icon: 'underline', label: 'Toggle underline' })
          }
          ValueNote({ text: `value = [${this.marks.join(', ')}]` })
          SToggleGroup({ type: 'single', sizing: 'sm', defaultValue: ['italic'] }) {
            SToggleGroupItem({ value: 'bold', icon: 'bold', label: 'Toggle bold' })
            SToggleGroupItem({ value: 'italic', icon: 'italic', label: 'Toggle italic' })
            SToggleGroupItem({ value: 'underline', icon: 'underline', label: 'Toggle underline' })
          }
          SToggleGroup({ type: 'single', sizing: 'lg', disabled: true }) {
            SToggleGroupItem({ value: 'bold', icon: 'bold', label: 'Toggle bold' })
            SToggleGroupItem({ value: 'italic', icon: 'italic', label: 'Toggle italic' })
          }
        }
      }

      DocSection({ title: 'Toggle Group — controlled' })
      DemoBlock({ code: TOGGLE_GROUP_CONTROLLED }) {
        Column({ space: 12 }) {
          SToggleGroup({ type: 'single', variant: 'outline', value: this.alignValue!! }) {
            SToggleGroupItem({ value: 'left', text: 'Left' })
            SToggleGroupItem({ value: 'center', text: 'Center' })
            SToggleGroupItem({ value: 'right', text: 'Right' })
          }
          ValueNote({ text: `value = [${this.alignValue.join(', ')}]` })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ ButtonGroup

const BUTTON_GROUP_CODE = `SButtonGroup() {
  SButton({ variant: 'ghost', text: 'Archive' })
  SButtonGroupSeparator()
  SButton({ variant: 'ghost', text: 'Report' })
  SButtonGroupSeparator()
  SButton({ variant: 'ghost', sizing: 'icon', icon: 'ellipsis', label: 'More' })
}`;

const BUTTON_GROUP_VERTICAL = `SButtonGroup({ orientation: 'vertical' }) {
  SButton({ variant: 'ghost', sizing: 'icon', icon: 'plus', label: 'Zoom in' })
  SButtonGroupSeparator()
  SButton({ variant: 'ghost', sizing: 'icon', icon: 'minus', label: 'Zoom out' })
}
// borderless group of filled buttons
SButtonGroup({ outlined: false }) {
  SButton({ text: 'Merge' })
  SButtonGroupSeparator()
  SButton({ sizing: 'icon', icon: 'chevron-down', label: 'More options' })
}`;

@ComponentV2
export struct ButtonGroupDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local last: string = '-';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Button Group',
        lead: 'A container that groups related buttons together with consistent styling. Use ghost buttons ' +
          'inside: the group draws the shared outline and clips the corners (slot children cannot be restyled).'
      })
      DemoBlock({ code: BUTTON_GROUP_CODE }) {
        Column({ space: 12 }) {
          SButtonGroup() {
            SButton({ variant: 'ghost', text: 'Archive' }).onClick(() => {
              this.last = 'Archive';
            })
            SButtonGroupSeparator()
            SButton({ variant: 'ghost', text: 'Report' }).onClick(() => {
              this.last = 'Report';
            })
            SButtonGroupSeparator()
            SButton({ variant: 'ghost', sizing: 'icon', icon: 'ellipsis', label: 'More' }).onClick(() => {
              this.last = 'More';
            })
          }
          ValueNote({ text: `last click: ${this.last}` })
        }
      }
      DocSection({ title: 'Orientation & borderless' })
      DemoBlock({ code: BUTTON_GROUP_VERTICAL }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center, space: space8 }) {
          SButtonGroup({ orientation: 'vertical' }) {
            SButton({ variant: 'ghost', sizing: 'icon', icon: 'plus', label: 'Zoom in' })
            SButtonGroupSeparator()
            SButton({ variant: 'ghost', sizing: 'icon', icon: 'minus', label: 'Zoom out' })
          }
          SButtonGroup({ outlined: false }) {
            SButton({ text: 'Merge' })
            SButtonGroupSeparator()
            SButton({ sizing: 'icon', icon: 'chevron-down', label: 'More options' })
          }
          SButtonGroup() {
            SButton({ variant: 'ghost', sizing: 'sm', text: 'Day' })
            SButtonGroupSeparator()
            SButton({ variant: 'ghost', sizing: 'sm', text: 'Week' })
            SButtonGroupSeparator()
            SButton({ variant: 'ghost', sizing: 'sm', text: 'Month' })
          }
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Breadcrumb

const BREADCRUMB_CODE = `SBreadcrumb() {
  SBreadcrumbList() {
    SBreadcrumbItem() { SBreadcrumbLink({ text: 'Home' }).onClick(() => this.go('home')) }
    SBreadcrumbSeparator()
    SBreadcrumbItem() { SBreadcrumbEllipsis() }
    SBreadcrumbSeparator()
    SBreadcrumbItem() { SBreadcrumbLink({ text: 'Components' }).onClick(() => this.go('components')) }
    SBreadcrumbSeparator()
    SBreadcrumbItem() { SBreadcrumbPage({ text: 'Breadcrumb' }) }
  }
}`;

const BREADCRUMB_CUSTOM = `// custom separator: icon '' + slot content
SBreadcrumbSeparator({ icon: '' }) { Text('/') }
SBreadcrumbSeparator({ icon: 'slash' })
// wraps instead of overflowing when narrow
Column() { SBreadcrumb() { ... } }.constraintSize({ maxWidth: 220 })`;

@ComponentV2
export struct BreadcrumbDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local visited: string = '-';

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Breadcrumb',
        lead: 'Displays the path to the current resource using a hierarchy of links.'
      })
      DemoBlock({ code: BREADCRUMB_CODE }) {
        Column({ space: 12 }) {
          SBreadcrumb() {
            SBreadcrumbList() {
              SBreadcrumbItem() {
                SBreadcrumbLink({ text: 'Home' }).onClick(() => {
                  this.visited = 'Home';
                })
              }
              SBreadcrumbSeparator()
              SBreadcrumbItem() {
                SBreadcrumbEllipsis()
              }
              SBreadcrumbSeparator()
              SBreadcrumbItem() {
                SBreadcrumbLink({ text: 'Components' }).onClick(() => {
                  this.visited = 'Components';
                })
              }
              SBreadcrumbSeparator()
              SBreadcrumbItem() {
                SBreadcrumbPage({ text: 'Breadcrumb' })
              }
            }
          }
          ValueNote({ text: `last link: ${this.visited}` })
        }
      }
      DocSection({ title: 'Custom separator & narrow width', description: 'The list wraps onto several ' +
        'lines instead of overflowing.' })
      DemoBlock({ code: BREADCRUMB_CUSTOM }) {
        Column({ space: 16 }) {
          SBreadcrumb() {
            SBreadcrumbList() {
              SBreadcrumbItem() {
                SBreadcrumbLink({ text: 'Home', icon: 'house' })
              }
              SBreadcrumbSeparator({ icon: '' }) {
                Text('/').fontSize(this.theme.text.sm).fontColor(this.theme.colors.mutedForeground)
              }
              SBreadcrumbItem() {
                SBreadcrumbLink({ text: 'Docs' })
              }
              SBreadcrumbSeparator({ icon: '' }) {
                Text('/').fontSize(this.theme.text.sm).fontColor(this.theme.colors.mutedForeground)
              }
              SBreadcrumbItem() {
                SBreadcrumbPage({ text: 'Breadcrumb' })
              }
            }
          }
          Column() {
            SBreadcrumb() {
              SBreadcrumbList() {
                SBreadcrumbItem() {
                  SBreadcrumbLink({ text: 'Home' })
                }
                SBreadcrumbSeparator()
                SBreadcrumbItem() {
                  SBreadcrumbLink({ text: 'Documentation' })
                }
                SBreadcrumbSeparator()
                SBreadcrumbItem() {
                  SBreadcrumbLink({ text: 'Building Your Application' })
                }
                SBreadcrumbSeparator()
                SBreadcrumbItem() {
                  SBreadcrumbLink({ text: 'Data Fetching' })
                }
                SBreadcrumbSeparator()
                SBreadcrumbItem() {
                  SBreadcrumbPage({ text: 'Caching and Revalidating' })
                }
              }
            }
          }
          .width(220)
          .padding(8)
          .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusMd })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ Pagination

const PAGINATION_CODE = `SPagination({ total: 10, defaultPage: 2 })`;

const PAGINATION_CONTROLLED = `@Local page: number = 5;

SPagination({ total: 20, page: this.page!!, siblingCount: 1 })`;

const PAGINATION_NARROW = `// below 480vp of its own width: icon-only Previous / Next, no sibling pages
Column() { SPagination({ total: 20, defaultPage: 10 }) }.width(340)`;

@ComponentV2
export struct PaginationDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Local page: number = 5;

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Pagination',
        lead: 'Pagination with page navigation, next and previous links. The page window comes from the pure ' +
          'function sparkPaginationRange(page, total, siblings) (-1 = ellipsis).'
      })
      DemoBlock({ code: PAGINATION_CODE }) {
        SPagination({ total: 10, defaultPage: 2 })
      }
      DocSection({ title: 'Controlled', description: 'Bind the 1-based page with !!.' })
      DemoBlock({ code: PAGINATION_CONTROLLED }) {
        Column({ space: 12 }) {
          SPagination({ total: 20, page: this.page!!, siblingCount: 1 })
          Row({ space: 8 }) {
            SButton({ text: 'First', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.page = 1;
            })
            SButton({ text: 'Last', variant: 'outline', sizing: 'sm' }).onClick(() => {
              this.page = 20;
            })
          }
          ValueNote({ text: `page = ${this.page}` })
        }
        .width('100%')
      }
      DocSection({ title: 'Responsive', description: 'Measures its own width: when narrower than 480vp the ' +
        'labels collapse to icons and siblingCount drops to 0.' })
      DemoBlock({ code: PAGINATION_NARROW }) {
        Column() {
          SPagination({ total: 20, defaultPage: 10 })
        }
        .width(340)
        .padding({ top: 8, bottom: 8 })
        .border({ width: 1, color: this.theme.colors.border, radius: this.theme.radiusMd })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

// ------------------------------------------------------------------------------------------------ ScrollArea

function makeTags(count: number): string[] {
  const out: string[] = [];
  for (let i = 0; i < count; i++) {
    out.push(`v1.2.0-beta.${count - i}`);
  }
  return out;
}

const SCROLL_AREA_CODE = `SScrollArea({ maxScrollHeight: 288, bordered: true }) {
  Column() {
    Text('Tags')
    ForEach(this.tags, (tag: string) => {
      Text(tag)
      Divider()
    }, (tag: string) => tag)
  }.padding(16)
}`;

const SCROLL_AREA_HORIZONTAL = `SScrollArea({ orientation: 'horizontal', bordered: true }) {
  Row({ space: 16 }) { ... }.padding(16)
}`;

@ComponentV2
export struct ScrollAreaDoc {
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  private tags: string[] = makeTags(50);
  private works: string[] = ['Ornella Binni', 'Tom Byrom', 'Vladimir Malyavko', 'Mira Ray', 'Leo Park'];

  build() {
    Column({ space: 16 }) {
      DocHeader({
        title: 'Scroll Area',
        lead: 'Native scrolling with a thin scrollbar that follows the theme (border token, 6vp).'
      })
      DemoBlock({ code: SCROLL_AREA_CODE }) {
        Column() {
          SScrollArea({ maxScrollHeight: 288, bordered: true }) {
            Column() {
              Text('Tags')
                .fontSize(this.theme.text.sm)
                .fontWeight(this.theme.text.weightMedium)
                .fontColor(this.theme.colors.foreground)
                .margin({ bottom: 16 })
              ForEach(this.tags, (tag: string) => {
                Column() {
                  Text(tag).fontSize(this.theme.text.sm).fontColor(this.theme.colors.foreground)
                  Divider().color(this.theme.colors.border).margin({ top: 8, bottom: 8 })
                }
                .alignItems(HorizontalAlign.Start)
              }, (tag: string) => tag)
            }
            .alignItems(HorizontalAlign.Start)
            .padding(16)
          }
        }
        .width(192)
      }
      DocSection({ title: 'Horizontal' })
      DemoBlock({ code: SCROLL_AREA_HORIZONTAL }) {
        Column() {
          SScrollArea({ orientation: 'horizontal', bordered: true }) {
            Row({ space: 16 }) {
              ForEach(this.works, (artist: string, i: number) => {
                Column({ space: 8 }) {
                  Column()
                    .width(150)
                    .height(200)
                    .backgroundColor(i % 2 === 0 ? this.theme.colors.muted : this.theme.colors.accent)
                    .border({ width: 0, radius: this.theme.radiusMd })
                  Text(`Photo by ${artist}`)
                    .fontSize(this.theme.text.xs)
                    .fontColor(this.theme.colors.mutedForeground)
                }
                .alignItems(HorizontalAlign.Start)
              }, (artist: string) => artist)
            }
            .padding(16)
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 384 })
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
