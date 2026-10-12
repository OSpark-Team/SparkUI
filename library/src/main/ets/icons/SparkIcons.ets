import { LUCIDE_ICONS } from './LucideIcons';
import { SparkIconData } from './SparkIconData';

/**
 * Icon registry. SparkUI components refer to icons by lucide name (e.g. 'chevron-down').
 * Apps can register extra icons, or map names to HarmonyOS Symbols so `SIcon` renders a `SymbolGlyph`.
 */
export class SparkIcons {
  private static custom: Map<string, SparkIconData> = new Map<string, SparkIconData>();
  private static symbols: Map<string, Resource> = new Map<string, Resource>();

  static register(name: string, data: SparkIconData): void {
    SparkIcons.custom.set(name, data);
  }

  static get(name: string): SparkIconData | undefined {
    return SparkIcons.custom.get(name) ?? LUCIDE_ICONS.get(name);
  }

  static has(name: string): boolean {
    return SparkIcons.get(name) !== undefined || SparkIcons.symbols.has(name);
  }

  /** Render `name` with a HarmonyOS Symbol instead of the vector path, e.g. `$r('sys.symbol.chevron_down')`. */
  static useSymbol(name: string, symbol: Resource): void {
    SparkIcons.symbols.set(name, symbol);
  }

  static symbolFor(name: string): Resource | undefined {
    return SparkIcons.symbols.get(name);
  }

  static names(): string[] {
    const all: string[] = [];
    LUCIDE_ICONS.forEach((_: SparkIconData, k: string) => {
      all.push(k);
    });
    SparkIcons.custom.forEach((_: SparkIconData, k: string) => {
      if (!all.includes(k)) {
        all.push(k);
      }
    });
    return all.sort();
  }
}
