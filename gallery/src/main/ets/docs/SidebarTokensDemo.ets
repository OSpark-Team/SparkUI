import { SparkUI, SSwitch } from '@sparkui/core';
import { DemoCaption } from '../shell/DocKit';

export const SIDEBAR_TOKENS_CODE = `// theme-wide (exported with the theme)
SparkUI.themes.setVariable('--sidebar-background', 'transparent');
SparkUI.themes.setVariable('--sidebar-menu-radius', '999px');
SparkUI.themes.setVariable('--sidebar-menu-active-background',
  'color-mix(in oklab, var(--primary) 12%, transparent)');
SparkUI.themes.setVariable('--sidebar-menu-active-foreground', 'var(--primary)');

// one sidebar only
SSidebarProvider({ tokens: { background: 'transparent', menuRadius: 999, borderColor: 'transparent' } }) { ... }`;

/** Sidebar look through --sidebar-* theme variables (live). */
@ComponentV2
export struct SidebarTokensDemo {
  @Local clear: boolean = SparkUI.themes.variable('--sidebar-background') !== undefined;
  @Local pill: boolean = SparkUI.themes.variable('--sidebar-menu-radius') !== undefined;

  private set(name: string, value: string | undefined): void {
    if (value === undefined) {
      SparkUI.themes.removeVariable(name);
    } else {
      SparkUI.themes.setVariable(name, value);
    }
  }

  @Computed
  get css(): string {
    const lines: string[] = [];
    if (this.clear) {
      lines.push('--sidebar-background: transparent;');
    }
    if (this.pill) {
      lines.push('--sidebar-menu-radius: 999px;', '--sidebar-menu-active-background: ' +
        'color-mix(in oklab, var(--primary) 12%, transparent);', '--sidebar-menu-active-foreground: var(--primary);');
    }
    return lines.length === 0 ? 'no --sidebar-* component tokens set — the shadcn recipe' : lines.join('  ');
  }

  build() {
    Column({ space: 12 }) {
      SSwitch({ label: 'Transparent sidebar (bordered)', checked: this.clear, onCheckedChange: (v: boolean) => {
        this.clear = v;
        this.set('--sidebar-background', v ? 'transparent' : undefined);
      } })
      SSwitch({ label: 'Pill menu buttons, primary tint', checked: this.pill, onCheckedChange: (v: boolean) => {
        this.pill = v;
        this.set('--sidebar-menu-radius', v ? '999px' : undefined);
        this.set('--sidebar-menu-active-background',
          v ? 'color-mix(in oklab, var(--primary) 12%, transparent)' : undefined);
        this.set('--sidebar-menu-active-foreground', v ? 'var(--primary)' : undefined);
      } })
      DemoCaption({ text: this.css })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
