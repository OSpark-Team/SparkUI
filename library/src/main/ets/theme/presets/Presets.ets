/**
 * Built-in theme presets, expressed in the very same CSS subset users load at runtime
 * (SparkUI dogfoods its own parser). Values match shadcn's v4 base colours; each preset is generated
 * from a Tailwind v4 gray family (oklch L C H per step).
 */

export class GrayScale {
  s50: string;
  s100: string;
  s200: string;
  s400: string;
  s500: string;
  s800: string;
  s900: string;
  s950: string;

  constructor(s50: string, s100: string, s200: string, s400: string, s500: string, s800: string, s900: string,
    s950: string) {
    this.s50 = s50;
    this.s100 = s100;
    this.s200 = s200;
    this.s400 = s400;
    this.s500 = s500;
    this.s800 = s800;
    this.s900 = s900;
    this.s950 = s950;
  }
}

export const NEUTRAL: GrayScale = new GrayScale(
  '0.985 0 0', '0.97 0 0', '0.922 0 0', '0.708 0 0', '0.556 0 0', '0.269 0 0', '0.205 0 0', '0.145 0 0');
export const ZINC: GrayScale = new GrayScale(
  '0.985 0 0', '0.967 0.001 286.375', '0.92 0.004 286.32', '0.705 0.015 286.067', '0.552 0.016 285.938',
  '0.274 0.006 286.033', '0.21 0.006 285.885', '0.141 0.005 285.823');
export const SLATE: GrayScale = new GrayScale(
  '0.984 0.003 247.858', '0.968 0.007 247.896', '0.929 0.013 255.508', '0.704 0.04 256.788',
  '0.554 0.046 257.417', '0.279 0.041 260.031', '0.208 0.042 265.755', '0.129 0.042 264.695');
export const STONE: GrayScale = new GrayScale(
  '0.985 0.001 106.423', '0.97 0.001 106.424', '0.923 0.003 48.717', '0.709 0.01 56.259', '0.553 0.013 58.071',
  '0.268 0.007 34.298', '0.216 0.006 56.043', '0.147 0.004 49.25');
export const GRAY: GrayScale = new GrayScale(
  '0.985 0.002 247.839', '0.967 0.003 264.542', '0.928 0.006 264.531', '0.707 0.022 261.325',
  '0.551 0.027 264.364', '0.278 0.033 256.848', '0.21 0.034 264.665', '0.13 0.028 261.692');

function o(v: string): string {
  return `oklch(${v})`;
}

/** Build a shadcn-style theme CSS from a gray family. */
export function buildGrayThemeCss(g: GrayScale): string {
  return `:root {
  --radius: 0.625rem;
  --background: oklch(1 0 0);
  --foreground: ${o(g.s950)};
  --card: oklch(1 0 0);
  --card-foreground: ${o(g.s950)};
  --popover: oklch(1 0 0);
  --popover-foreground: ${o(g.s950)};
  --primary: ${o(g.s900)};
  --primary-foreground: ${o(g.s50)};
  --secondary: ${o(g.s100)};
  --secondary-foreground: ${o(g.s900)};
  --muted: ${o(g.s100)};
  --muted-foreground: ${o(g.s500)};
  --accent: ${o(g.s100)};
  --accent-foreground: ${o(g.s900)};
  --destructive: oklch(0.577 0.245 27.325);
  --destructive-foreground: oklch(1 0 0);
  --border: ${o(g.s200)};
  --input: ${o(g.s200)};
  --ring: ${o(g.s400)};
  --chart-1: oklch(0.646 0.222 41.116);
  --chart-2: oklch(0.6 0.118 184.704);
  --chart-3: oklch(0.398 0.07 227.392);
  --chart-4: oklch(0.828 0.189 84.429);
  --chart-5: oklch(0.769 0.188 70.08);
  --sidebar: ${o(g.s50)};
  --sidebar-foreground: ${o(g.s950)};
  --sidebar-primary: ${o(g.s900)};
  --sidebar-primary-foreground: ${o(g.s50)};
  --sidebar-accent: ${o(g.s100)};
  --sidebar-accent-foreground: ${o(g.s900)};
  --sidebar-border: ${o(g.s200)};
  --sidebar-ring: ${o(g.s400)};
}

.dark {
  --background: ${o(g.s950)};
  --foreground: ${o(g.s50)};
  --card: ${o(g.s900)};
  --card-foreground: ${o(g.s50)};
  --popover: ${o(g.s900)};
  --popover-foreground: ${o(g.s50)};
  --primary: ${o(g.s200)};
  --primary-foreground: ${o(g.s900)};
  --secondary: ${o(g.s800)};
  --secondary-foreground: ${o(g.s50)};
  --muted: ${o(g.s800)};
  --muted-foreground: ${o(g.s400)};
  --accent: ${o(g.s800)};
  --accent-foreground: ${o(g.s50)};
  --destructive: oklch(0.704 0.191 22.216);
  --destructive-foreground: oklch(1 0 0);
  --border: oklch(1 0 0 / 10%);
  --input: oklch(1 0 0 / 15%);
  --ring: ${o(g.s500)};
  --chart-1: oklch(0.488 0.243 264.376);
  --chart-2: oklch(0.696 0.17 162.48);
  --chart-3: oklch(0.769 0.188 70.08);
  --chart-4: oklch(0.627 0.265 303.9);
  --chart-5: oklch(0.645 0.246 16.439);
  --sidebar: ${o(g.s900)};
  --sidebar-foreground: ${o(g.s50)};
  --sidebar-primary: oklch(0.488 0.243 264.376);
  --sidebar-primary-foreground: ${o(g.s50)};
  --sidebar-accent: ${o(g.s800)};
  --sidebar-accent-foreground: ${o(g.s50)};
  --sidebar-border: oklch(1 0 0 / 10%);
  --sidebar-ring: ${o(g.s500)};
}
`;
}

export type SparkPresetName = 'neutral' | 'zinc' | 'slate' | 'stone' | 'gray';

export const SPARK_PRESETS: SparkPresetName[] = ['neutral', 'zinc', 'slate', 'stone', 'gray'];

export function presetCss(name: string): string | undefined {
  switch (name) {
    case 'neutral':
      return buildGrayThemeCss(NEUTRAL);
    case 'zinc':
      return buildGrayThemeCss(ZINC);
    case 'slate':
      return buildGrayThemeCss(SLATE);
    case 'stone':
      return buildGrayThemeCss(STONE);
    case 'gray':
      return buildGrayThemeCss(GRAY);
    default:
      return undefined;
  }
}

/**
 * Accent colour themes (shadcn "themes"): layered on top of a gray base preset, they recolour
 * primary / ring / sidebar-primary / charts. Steps are Tailwind v4 oklch values:
 * light uses 600 (yellow 400) with a 50 foreground, dark uses 500 (yellow 500).
 */
export type SparkAccentName = 'none' | 'blue' | 'green' | 'orange' | 'red' | 'rose' | 'violet' | 'yellow';

export const SPARK_ACCENTS: SparkAccentName[] = ['none', 'blue', 'green', 'orange', 'red', 'rose', 'violet', 'yellow'];

class AccentScale {
  light: string;
  lightFg: string;
  dark: string;
  darkFg: string;
  ring: string;

  constructor(light: string, lightFg: string, dark: string, darkFg: string, ring: string) {
    this.light = light;
    this.lightFg = lightFg;
    this.dark = dark;
    this.darkFg = darkFg;
    this.ring = ring;
  }
}

function accentScale(name: string): AccentScale | undefined {
  switch (name) {
    case 'blue':
      return new AccentScale('0.546 0.245 262.881', '0.97 0.014 254.604', '0.623 0.214 259.815',
        '0.97 0.014 254.604', '0.707 0.165 254.624');
    case 'green':
      return new AccentScale('0.627 0.194 149.214', '0.982 0.018 155.826', '0.723 0.219 149.579',
        '0.266 0.065 152.934', '0.792 0.209 151.711');
    case 'orange':
      return new AccentScale('0.646 0.222 41.116', '0.98 0.016 73.684', '0.705 0.213 47.604',
        '0.98 0.016 73.684', '0.75 0.183 55.934');
    case 'red':
      return new AccentScale('0.577 0.245 27.325', '0.971 0.013 17.38', '0.637 0.237 25.331',
        '0.971 0.013 17.38', '0.704 0.191 22.216');
    case 'rose':
      return new AccentScale('0.586 0.253 17.585', '0.969 0.015 12.422', '0.645 0.246 16.439',
        '0.969 0.015 12.422', '0.712 0.194 13.428');
    case 'violet':
      return new AccentScale('0.541 0.281 293.009', '0.969 0.016 293.756', '0.606 0.25 292.717',
        '0.969 0.016 293.756', '0.702 0.183 293.541');
    case 'yellow':
      return new AccentScale('0.852 0.199 91.936', '0.421 0.095 57.708', '0.795 0.184 86.047',
        '0.421 0.095 57.708', '0.852 0.199 91.936');
    default:
      return undefined;
  }
}

/** CSS overlay for an accent theme ('' for 'none'). */
export function accentCss(name: string): string {
  const a = accentScale(name);
  if (a === undefined) {
    return '';
  }
  return `:root {
  --primary: oklch(${a.light});
  --primary-foreground: oklch(${a.lightFg});
  --ring: oklch(${a.ring});
  --sidebar-primary: oklch(${a.light});
  --sidebar-primary-foreground: oklch(${a.lightFg});
  --sidebar-ring: oklch(${a.ring});
}
.dark {
  --primary: oklch(${a.dark});
  --primary-foreground: oklch(${a.darkFg});
  --ring: oklch(${a.dark});
  --sidebar-primary: oklch(${a.dark});
  --sidebar-primary-foreground: oklch(${a.darkFg});
  --sidebar-ring: oklch(${a.dark});
}
`;
}
