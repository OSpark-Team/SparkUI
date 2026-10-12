import { UIContext } from '@kit.ArkUI';

/**
 * Turns a `ResourceStr` prop into a plain string: a string is returned unchanged, a resource is
 * resolved through `sparkText` (and falls back to the English literal if it cannot be read).
 */
export function sparkTextOf(ui: UIContext | undefined, value: ResourceStr, fallback: string): string {
  if (typeof value === 'string') {
    return value;
  }
  return sparkText(ui, value, fallback);
}

/**
 * Resolves a library string resource (`$r('app.string.spark_*')`) at runtime, so that
 * plain `string` APIs follow the system language. Falls back to the English literal
 * when the host context or the resource is unavailable.
 */
export function sparkText(ui: UIContext | undefined, res: Resource, fallback: string): string {
  try {
    const rm = ui?.getHostContext()?.resourceManager;
    if (rm !== undefined) {
      return rm.getStringSync(res.id);
    }
  } catch (err) {
    // fall through to the English fallback
  }
  return fallback;
}

/** Like `sparkText`, for a `%s` / `%d` placeholder resource with one argument. */
export function sparkTextArg(ui: UIContext | undefined, res: Resource, fallback: string, arg: string | number): string {
  try {
    const rm = ui?.getHostContext()?.resourceManager;
    if (rm !== undefined) {
      return rm.getStringSync(res.id, arg);
    }
  } catch (err) {
    // fall through to the English fallback
  }
  return fallback;
}

/** Like `sparkText`, for a resource with two placeholders, e.g. `Step %d: %s (%s)`. */
export function sparkTextArgs2(ui: UIContext | undefined, res: Resource, fallback: string, a: string | number,
  b: string | number): string {
  try {
    const rm = ui?.getHostContext()?.resourceManager;
    if (rm !== undefined) {
      return rm.getStringSync(res.id, a, b);
    }
  } catch (err) {
    // fall through to the English fallback
  }
  return fallback;
}

/** Like `sparkText`, for a resource with three placeholders, e.g. `Step %d: %s (%s)`. */
export function sparkTextArgs3(ui: UIContext | undefined, res: Resource, fallback: string, a: string | number,
  b: string | number, c: string | number): string {
  try {
    const rm = ui?.getHostContext()?.resourceManager;
    if (rm !== undefined) {
      return rm.getStringSync(res.id, a, b, c);
    }
  } catch (err) {
    // fall through to the English fallback
  }
  return fallback;
}
