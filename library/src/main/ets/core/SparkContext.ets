/**
 * Render-tree context for compound components.
 *
 * Verified on device (docs/iterations/round-01-foundation.md): a `@Consumer` placed in trailing-closure
 * slot content resolves against the component that *defines* the builder (usually the page), not the
 * component that *hosts* the slot. `STabs { STabsTrigger() }` therefore cannot share state through
 * `@Provider/@Consumer`.
 *
 * SparkContext resolves along the real render tree instead. A host registers a value under its
 * component id. A descendant walks its FrameNode ancestors and matches each against the hosts' root
 * render nodes. The descendant's FrameNode exists from `onDidBuild()` onward, so resolve there:
 *
 * ```
 * // host
 * aboutToAppear() { SparkContext.provide(this.getUIContext(), this.getUniqueId(), 'tabs', this.state); }
 * aboutToDisappear() { SparkContext.revoke(this.getUniqueId()); }
 * // descendant
 * @Local tabs: TabsState | undefined = undefined;
 * onDidBuild() { this.tabs ??= SparkContext.resolve<TabsState>(this.getUIContext(), this.getUniqueId(), 'tabs'); }
 * ```
 * Overlay content is reached the same way: the overlay root component registers itself as a host.
 */
class HostEntry {
  key: string;
  value: Object;
  /** uniqueId of the host's root render node; -1 until it exists */
  rootNodeId: number = -1;
  uiContext: UIContext;

  constructor(uiContext: UIContext, key: string, value: Object) {
    this.uiContext = uiContext;
    this.key = key;
    this.value = value;
  }
}

export class SparkContext {
  /** component uniqueId → entries */
  private static hosts: Map<number, HostEntry[]> = new Map<number, HostEntry[]>();
  /** root render node uniqueId → component uniqueId */
  private static byNode: Map<number, number> = new Map<number, number>();

  static provide(uiContext: UIContext, componentId: number, key: string, value: Object): void {
    const list = SparkContext.hosts.get(componentId) ?? [];
    const existing = list.find((e: HostEntry) => e.key === key);
    if (existing !== undefined) {
      existing.value = value;
    } else {
      list.push(new HostEntry(uiContext, key, value));
    }
    SparkContext.hosts.set(componentId, list);
  }

  static revoke(componentId: number): void {
    const list = SparkContext.hosts.get(componentId);
    if (list !== undefined) {
      list.forEach((e: HostEntry) => {
        if (e.rootNodeId >= 0) {
          SparkContext.byNode.delete(e.rootNodeId);
        }
      });
    }
    SparkContext.hosts.delete(componentId);
  }

  /** Nearest ancestor host value registered under `key`, or undefined. */
  static resolve<T>(uiContext: UIContext, selfComponentId: number, key: string): T | undefined {
    SparkContext.indexPendingHosts();
    let node = uiContext.getFrameNodeByUniqueId(selfComponentId);
    const selfRoot = node === null ? -1 : node.getUniqueId();
    let hops = 0;
    while (node !== null && hops < 512) {
      const nodeId = node.getUniqueId();
      if (nodeId !== selfRoot) {
        const hostId = SparkContext.byNode.get(nodeId);
        if (hostId !== undefined && hostId !== selfComponentId) {
          const list = SparkContext.hosts.get(hostId);
          const hit = list?.find((e: HostEntry) => e.key === key);
          if (hit !== undefined) {
            return hit.value as T;
          }
        }
      }
      node = node.getParent();
      hops++;
    }
    return undefined;
  }

  /**
   * Run `fn` once the component's render node is attached to the tree — immediately when it already is,
   * otherwise on the next frames. Components created by ForEach / LazyForEach / if run onDidBuild before
   * they are mounted, so getFrameNodeByUniqueId() is still null there (verified on device). Use for all
   * SparkContext resolution:
   * ```
   * onDidBuild() { SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve()); }
   * ```
   */
  static whenAttached(uiContext: UIContext, componentId: number, fn: () => void, tries?: number): void {
    const left = tries ?? 20;
    let attached = false;
    try {
      attached = uiContext.getFrameNodeByUniqueId(componentId) !== null;
    } catch (e) {
      attached = false;
    }
    if (attached || left <= 0) {
      fn();
      return;
    }
    setTimeout(() => SparkContext.whenAttached(uiContext, componentId, fn, left - 1), 16);
  }

  /** Number of live hosts (for tests / the layout inspector). */
  static get size(): number {
    return SparkContext.hosts.size;
  }

  private static indexPendingHosts(): void {
    SparkContext.hosts.forEach((list: HostEntry[], componentId: number) => {
      list.forEach((e: HostEntry) => {
        if (e.rootNodeId >= 0) {
          return;
        }
        const n = e.uiContext.getFrameNodeByUniqueId(componentId);
        if (n !== null) {
          e.rootNodeId = n.getUniqueId();
          SparkContext.byNode.set(e.rootNodeId, componentId);
        }
      });
    });
  }
}
