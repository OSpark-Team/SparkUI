/**
 * Web imitations of the SparkUI layout blocks: SSidebarProvider + SSidebar family, STopbar, SAppShell, SListDetail,
 * SSupportingPane, SDashboardGrid / SDashboardTile. (STitleBar is window chrome: its docs page shows code only.)
 *
 * Like the library they are breakpoint-free: every block measures its own container (ResizeObserver) and runs the
 * same policies with the same numbers as library/src/main/ets/blocks/BlocksLogic.ets — the sidebar docks when the
 * expanded sidebar fits next to `minInsetWidth` (else it becomes a sheet), list / detail sit side by side when
 * the detail keeps `minDetailWidth`, the supporting pane moves below / into a sheet when the main area would drop
 * under `minMainWidth`, the top bar condenses below 520 px. Before the first measurement (SSR) the wide layouts
 * are used for the sidebar and the narrow ones for the split panes, as in the library (width 0 = "not measured").
 */
import { h, ref, reactive, computed, watch, provide, inject, defineComponent, onMounted, onBeforeUnmount, Teleport } from 'vue';
import { icon } from './icons.js';
import { len } from './runtime.js';
import { isEnumProxy } from './interp.js';
import { tokenVars } from './tokens.js';

// ------------------------------------------------------------------------------------------------ BlocksLogic

export const SIDEBAR_WIDTH = 256;
export const SIDEBAR_WIDTH_MOBILE = 288;
export const SIDEBAR_WIDTH_ICON = 48;
export const SIDEBAR_FRAME_GAP = 8;
export const TOPBAR_CONDENSED_BELOW = 520;

export function sidebarDockWidth(open, collapsible, variant, sidebarWidth, railWidth = SIDEBAR_WIDTH_ICON, frameGap = SIDEBAR_FRAME_GAP) {
  if (open || collapsible === 'none') {
    return sidebarWidth;
  }
  if (collapsible === 'icon') {
    return variant === 'sidebar' ? railWidth : railWidth + frameGap * 2;
  }
  return 0;
}

export function sidebarIsMobile(containerWidth, sidebarWidth, minInsetWidth, collapsible) {
  if (collapsible === 'none' || containerWidth <= 0) {
    return false;
  }
  return containerWidth < sidebarWidth + minInsetWidth;
}

export function sidebarSheetWidth(windowWidth, mobileWidth) {
  if (windowWidth <= 0) {
    return mobileWidth;
  }
  return Math.min(mobileWidth, Math.floor(windowWidth * 0.85));
}

export function listDetailWide(width, listWidth, minDetailWidth) {
  if (width <= 0) {
    return false;
  }
  return width >= listWidth + 1 + minDetailWidth;
}

export function listPaneWidth(width, listWidth, wide) {
  if (!wide) {
    return width;
  }
  return Math.min(listWidth, Math.floor(width * 0.45));
}

export function supportingWide(width, paneWidth, minMainWidth) {
  if (width <= 0) {
    return false;
  }
  return width >= paneWidth + minMainWidth;
}

export function topbarCondensed(width, below = TOPBAR_CONDENSED_BELOW) {
  return width > 0 && width < below;
}

export function sidebarDefaultPolicy(input) {
  return sidebarIsMobile(input.containerWidth, input.sidebarWidth, input.minInsetWidth, input.collapsible) ? 'sheet' : 'docked';
}

export function sidebarRowWidth(presentation, open, collapsible, variant, sidebarWidth, railWidth, frameGap) {
  if (presentation === 'sheet') {
    return 0;
  }
  if (presentation === 'rail') {
    return sidebarDockWidth(false, 'icon', variant, sidebarWidth, railWidth, frameGap);
  }
  return sidebarDockWidth(open, collapsible, variant, sidebarWidth, railWidth, frameGap);
}

// ------------------------------------------------------------------------------------------------ helpers

function txt(v) {
  if (v === undefined || v === null || (typeof v === 'object' && !isEnumProxy(v))) {
    return '';
  }
  return String(v);
}

function en(v, fallback) {
  if (v === undefined || v === null) {
    return fallback;
  }
  return String(v).split('.').pop();
}

function call(fn, ...args) {
  if (typeof fn === 'function') {
    try {
      return fn(...args);
    } catch (e) {
      return undefined;
    }
  }
  return undefined;
}

/** A synthetic node descriptor (what runtime.describe produces) for composing components in JS. */
function node(props = {}, children = () => [], extra = {}) {
  return {
    name: extra.name || 'Node', props, args: [props], binds: {}, refs: {}, slots: {}, attrs: [], attr: () => undefined,
    style: {}, events: {}, children, hasChildren: true, ...extra
  };
}

const def = (name, setup) => defineComponent({ name, props: { n: { type: Object, required: true } }, setup });
const C = (comp) => (n) => h(comp, { n });

/** Measured width of an element (0 until measured). */
function useWidth() {
  const el = ref(null);
  const width = ref(0);
  let ro = null;
  onMounted(() => {
    if (!el.value) {
      return;
    }
    width.value = el.value.getBoundingClientRect().width;
    if (typeof ResizeObserver !== 'undefined') {
      ro = new ResizeObserver((entries) => {
        const w = entries[0]?.contentRect?.width ?? 0;
        if (Math.abs(w - width.value) > 0.5) {
          width.value = w;
        }
      });
      ro.observe(el.value);
    }
  });
  onBeforeUnmount(() => ro?.disconnect());
  return { el, width };
}

/** Controlled (`prop` / `prop!!`) or uncontrolled (`defaultProp`) value with change events. */
function useControlled(props, key, defKey, fallback, events) {
  const p = () => props.n.props;
  const local = ref(p()[key] !== undefined ? p()[key] : (p()[defKey] !== undefined ? p()[defKey] : fallback));
  watch(() => props.n.props[key], (v) => {
    if (v !== undefined) {
      local.value = v;
    }
  });
  const set = (v) => {
    if (v === local.value) {
      return;
    }
    local.value = v;
    props.n.binds[key]?.(v);
    for (const e of events) {
      call(props.n.props[e], v);
    }
  };
  return [local, set];
}

function ghostIcon(reg, iconName, label, onClick, extra = {}) {
  return reg.SButton(node({ variant: 'ghost', sizing: 'icon-sm', icon: iconName, label }, () => [], { events: { onClick: (e) => { e?.stopPropagation?.(); onClick(); } }, ...extra }));
}

function slot(n, name, ...args) {
  const s = n.slots?.[name];
  return s ? s(...args) : [];
}

function blockHeight(n, fallback) {
  return n.style?.height ? undefined : `${fallback}px`;
}

// ------------------------------------------------------------------------------------------------ sidebar

const SIDEBAR_KEY = Symbol('sidebar');
const SHEET_KEY = Symbol('sidebar-sheet');

function sidebarState() {
  return reactive({
    open: true, openMobile: false, presentation: 'docked', variant: 'sidebar', collapsible: 'offcanvas', side: 'left',
    value: '', width: 0, sidebarWidth: SIDEBAR_WIDTH, mobileWidth: SIDEBAR_WIDTH_MOBILE, railWidth: SIDEBAR_WIDTH_ICON,
    frameGap: SIDEBAR_FRAME_GAP, minInsetWidth: 360, closeOnSelect: true,
    get dockWidth() {
      return sidebarRowWidth(this.presentation, this.open, this.collapsible, this.variant, this.sidebarWidth, this.railWidth, this.frameGap);
    },
    get collapsed() {
      return this.presentation === 'rail' || (this.presentation === 'docked' && !this.open && this.collapsible !== 'none');
    },
    get iconOnly() {
      return this.presentation === 'rail' || (this.collapsed && this.collapsible === 'icon');
    },
    get insetFramed() {
      return this.presentation !== 'sheet' && this.variant === 'inset';
    },
    get toggleable() {
      return this.presentation !== 'docked' || this.collapsible !== 'none';
    },
    setOpen: null,
    select: null,
    toggle() {
      if (this.presentation !== 'docked') {
        this.openMobile = !this.openMobile;
      } else if (this.collapsible !== 'none') {
        this.setOpen(!this.open);
      }
    }
  });
}

const SidebarProvider = def('SSidebarProvider', (props) => {
  const s = sidebarState();
  const [open, setOpen] = useControlled(props, 'open', 'defaultOpen', true, ['onOpenChange']);
  const [value, setValue] = useControlled(props, 'value', 'defaultValue', '', ['onValueChange']);
  const { el, width } = useWidth();
  s.setOpen = setOpen;
  s.select = (v) => {
    if (v) {
      setValue(v);
      call(props.n.props.onNavigate, v);
    }
    if (s.presentation !== 'docked' && s.closeOnSelect) {
      s.openMobile = false;
    }
  };
  const sync = () => {
    const o = props.n.props;
    s.open = open.value;
    s.value = value.value;
    s.variant = en(o.variant, props.n.defaultVariant || 'sidebar');
    s.collapsible = en(o.collapsible, props.n.defaultCollapsible || 'offcanvas');
    s.side = en(o.side, 'left');
    s.sidebarWidth = o.sidebarWidth > 0 ? o.sidebarWidth : SIDEBAR_WIDTH;
    s.mobileWidth = o.sidebarWidthMobile > 0 ? o.sidebarWidthMobile : SIDEBAR_WIDTH_MOBILE;
    s.minInsetWidth = o.minInsetWidth ?? 360;
    s.closeOnSelect = o.closeOnSelect !== false;
    s.width = width.value;
    const input = { containerWidth: s.width, sidebarWidth: s.sidebarWidth, railWidth: s.railWidth, minInsetWidth: s.minInsetWidth, collapsible: s.collapsible };
    let p = typeof o.layoutPolicy === 'function' ? call(o.layoutPolicy, input) : undefined;
    if (p !== 'docked' && p !== 'rail' && p !== 'sheet') {
      p = sidebarDefaultPolicy(input);
    }
    if (p !== s.presentation) {
      s.presentation = p;
      if (p === 'docked') {
        s.openMobile = false;
      }
      call(o.onPresentationChange, p);
    }
  };
  watch([open, value, width, () => props.n.props], sync, { immediate: true, deep: false });
  watch(() => s.openMobile, (v) => call(props.n.props.onOpenMobileChange, v));
  provide(SIDEBAR_KEY, s);
  return () => {
    sync();
    const n = props.n;
    const kids = n.children();
    return h('div', {
      ref: el,
      class: ['ark-sb-provider', `variant-${s.variant}`, `side-${s.side}`, `is-${s.presentation}`, s.collapsed && 'collapsed'],
      // an elided body (`{ ... }` in a snippet) gets a short frame instead of an empty window
      style: [{ height: kids.length ? blockHeight(n, 460) : '96px' }, tokenVars('sidebar', n.props.tokens), n.style],
      'data-state': s.collapsed ? 'collapsed' : 'expanded',
      ...n.events
    }, kids);
  };
});

const Sidebar = def('SSidebar', (props) => {
  const s = inject(SIDEBAR_KEY, null);
  return () => {
    const n = props.n;
    if (!s) {
      return h('aside', { class: 'ark-sb-panel standalone', style: n.style }, n.children());
    }
    const framed = s.variant !== 'sidebar';
    const panel = (inSheet) => h(SheetMark, { inSheet }, () => n.children());
    const kids = [];
    if (s.presentation !== 'sheet') {
      kids.push(h('div', {
        class: ['ark-sb-dock', framed && 'framed', s.iconOnly && 'icon-only'],
        style: { width: `${s.dockWidth}px`, padding: framed ? `${s.frameGap}px` : undefined }
      }, h('aside', {
        class: ['ark-sb-panel', `variant-${s.variant}`],
        style: { width: s.collapsible === 'offcanvas' && s.presentation === 'docked' ? `${s.sidebarWidth}px` : '100%' }
      }, panel(false))));
    }
    if (s.presentation !== 'docked' && s.openMobile) {
      kids.push(h('div', { class: 'ark-sb-sheet-layer' }, [
        h('div', { class: 'ark-sb-backdrop', onClick: () => (s.openMobile = false) }),
        h('aside', {
          class: ['ark-sb-panel', 'ark-sb-sheet', `side-${s.side}`],
          style: { width: `${sidebarSheetWidth(s.width, s.mobileWidth)}px` }
        }, panel(true))
      ]));
    }
    return kids;
  };
});

/** Marks content rendered in the sheet (labels stay visible over an icon rail). */
const SheetMark = defineComponent({
  name: 'SidebarSheetMark',
  props: { inSheet: Boolean },
  setup(props, { slots }) {
    provide(SHEET_KEY, computed(() => props.inSheet));
    return () => h('div', { class: 'ark-sb-inner' }, slots.default?.());
  }
});

function useIconOnly() {
  const s = inject(SIDEBAR_KEY, null);
  const sheet = inject(SHEET_KEY, ref(false));
  return computed(() => !sheet.value && !!s?.iconOnly);
}

const sbSection = (cls) => (n) => h('div', { class: cls, style: n.style, ...n.events }, n.children());

const SidebarGroupLabel = def('SSidebarGroupLabel', (props) => {
  const iconOnly = useIconOnly();
  return () => h('div', { class: ['ark-sb-group-label', iconOnly.value && 'hidden'], style: props.n.style },
    [txt(props.n.props.text), ...props.n.children()]);
});

const SidebarMenuButton = def('SSidebarMenuButton', (props) => {
  const s = inject(SIDEBAR_KEY, null);
  const iconOnly = useIconOnly();
  return () => {
    const n = props.n;
    const o = n.props;
    const active = o.isActive !== undefined ? !!o.isActive : !!(s && o.value && s.value === o.value);
    const sizing = o.sizing || 'default';
    return h('button', {
      class: ['ark-sb-menu-button', `size-${sizing}`, `variant-${o.variant || 'default'}`, active && 'active', iconOnly.value && 'icon-only', o.disabled && 'disabled'],
      style: n.style,
      title: iconOnly.value ? txt(o.text) : undefined,
      'aria-current': active ? 'page' : undefined,
      disabled: !!o.disabled,
      onClick: (e) => {
        n.events.onClick?.(e);
        if (o.disabled) {
          return;
        }
        call(o.onSelect);
        s?.select?.(o.value);
      }
    }, [
      o.icon ? icon(o.icon, 16) : null,
      h('span', { class: 'ark-sb-menu-text' }, txt(o.text)),
      o.badge !== undefined ? h('span', { class: 'ark-sb-menu-badge' }, txt(o.badge)) : null,
      ...n.children()
    ]);
  };
});

function sidebarTrigger(reg) {
  return def('SSidebarTrigger', (props) => {
    const s = inject(SIDEBAR_KEY, null);
    return () => {
      const o = props.n.props;
      const ic = o.icon ?? (s?.side === 'right' ? 'panel-right' : 'panel-left');
      return h('span', { class: 'ark-sb-trigger', style: props.n.style }, ghostIcon(reg, ic, o.label ?? 'Toggle Sidebar', () => s?.toggle()));
    };
  });
}

const SidebarInset = def('SSidebarInset', (props) => {
  const s = inject(SIDEBAR_KEY, null);
  return () => {
    const n = props.n;
    const framed = !!s?.insetFramed;
    let margin;
    if (framed) {
      const g = s.frameGap;
      const near = s.dockWidth > 0 ? 0 : g;
      margin = s.side === 'left' ? `${g}px ${g}px ${g}px ${near}px` : `${g}px ${near}px ${g}px ${g}px`;
    }
    return h('main', { class: ['ark-sb-inset', framed && 'framed'], style: [{ margin }, n.style], ...n.events }, n.children());
  };
});

// ------------------------------------------------------------------------------------------------ top bar

function topbar(reg) {
  return def('STopbar', (props) => {
    const s = inject(SIDEBAR_KEY, null);
    const { el, width } = useWidth();
    const searchOpen = ref(false);
    return () => {
      const n = props.n;
      const o = n.props;
      const condensed = topbarCondensed(width.value, o.condenseBelow ?? TOPBAR_CONDENSED_BELOW);
      if (!condensed && searchOpen.value) {
        searchOpen.value = false;
      }
      const leading = en(o.leading, 'auto');
      const showTrigger = leading === 'trigger' || (leading === 'auto' && !!s?.toggleable);
      const kids = [];
      const searchField = () => h('div', { class: 'ark-topbar-search' }, reg.SInput(node({
        placeholder: o.searchPlaceholder ?? 'Search…', icon: 'search', sizing: 'sm',
        onValueChange: (v) => call(o.onSearchChange, v), onSubmit: (v) => call(o.onSearch, v)
      })));
      if (condensed && searchOpen.value) {
        kids.push(h('div', { class: 'ark-topbar-grow' }, searchField()));
        kids.push(ghostIcon(reg, 'x', 'Close search', () => (searchOpen.value = false)));
      } else {
        if (showTrigger) {
          kids.push(h('span', { class: 'ark-sb-trigger' }, ghostIcon(reg, s?.side === 'right' ? 'panel-right' : 'panel-left', 'Toggle Sidebar', () => s?.toggle())));
        } else if (leading === 'back') {
          kids.push(ghostIcon(reg, 'arrow-left', 'Back', () => call(o.onBack)));
        }
        kids.push(...slot(n, 'leadingBuilder'));
        if ((showTrigger || leading === 'back') && !condensed) {
          kids.push(h('span', { class: 'ark-topbar-sep' }));
        }
        const title = txt(o.title);
        kids.push(h('div', { class: 'ark-topbar-titles' }, [
          title ? h('div', { class: ['ark-topbar-title', condensed && 'condensed'] }, title) : null,
          o.subtitle !== undefined && !condensed ? h('div', { class: 'ark-topbar-subtitle' }, txt(o.subtitle)) : null,
          ...slot(n, 'titleBuilder')
        ]));
        if (o.search) {
          if (condensed) {
            kids.push(ghostIcon(reg, 'search', o.searchPlaceholder ?? 'Search…', () => (searchOpen.value = true)));
          } else {
            kids.push(h('div', { style: { width: `${Math.min(260, Math.max(160, width.value * 0.3))}px` } }, searchField()));
          }
        }
        for (const a of Array.isArray(o.actions) ? o.actions : []) {
          const id = a?.id ?? a?.args?.[0];
          kids.push(ghostIcon(reg, a?.icon ?? a?.args?.[1], a?.label ?? a?.args?.[2], () => call(o.onAction, id)));
        }
        kids.push(...n.children());
      }
      return h('header', {
        ref: el,
        class: ['ark-topbar', condensed && 'condensed', o.translucent && 'translucent', o.bordered === false && 'borderless'],
        style: [o.barHeight > 0 ? { height: `${o.barHeight}px` } : {}, tokenVars('topbar', o.tokens), n.style],
        ...n.events
      }, kids);
    };
  });
}

// ------------------------------------------------------------------------------------------------ app shell

const NAV_LABEL = (g) => g?.title ?? g?.args?.[0] ?? '';
const NAV_ITEMS = (g) => g?.items ?? g?.args?.[1] ?? [];
const ITEM = (it) => ({
  id: it?.id ?? it?.args?.[0], title: it?.title ?? it?.args?.[1], icon: it?.icon ?? it?.args?.[2],
  badge: it?.badge ?? it?.args?.[3], disabled: it?.disabled ?? it?.args?.[4]
});

function initials(name) {
  const parts = String(name || '').trim().split(' ').filter(Boolean);
  if (!parts.length) {
    return '';
  }
  return (parts[0][0] + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase();
}

function appShell(reg, parts) {
  const shellBrand = (o) => h('div', { class: 'ark-shell-brand' }, [
    h('span', { class: 'ark-shell-brand-icon' }, icon(o.brandIcon ?? 'sparkles', 16)),
    h('div', { class: 'ark-shell-brand-text' }, [
      h('div', { class: 'ark-shell-brand-name' }, txt(o.brand)),
      o.brandDetail !== undefined ? h('div', { class: 'ark-shell-brand-detail' }, txt(o.brandDetail)) : null
    ])
  ]);
  const shellUser = (u) => {
    const name = u?.name ?? u?.args?.[0] ?? '';
    const detail = u?.detail ?? u?.args?.[1] ?? '';
    return h('div', { class: 'ark-shell-user' }, [
      reg.SAvatar(node({ fallback: initials(name), sizing: 32, src: u?.avatar })),
      h('div', { class: 'ark-shell-brand-text' }, [
        h('div', { class: 'ark-shell-user-name' }, txt(name)),
        h('div', { class: 'ark-shell-brand-detail' }, txt(detail))
      ])
    ]);
  };
  return def('SAppShell', (props) => {
    const [value, setValue] = useControlled(props, 'value', 'defaultValue', '', ['onValueChange']);
    return () => {
      const n = props.n;
      const o = n.props;
      const nav = Array.isArray(o.nav) ? o.nav : [];
      let title = o.title;
      if (title === undefined) {
        for (const g of nav) {
          for (const it of NAV_ITEMS(g)) {
            if (ITEM(it).id === value.value) {
              title = ITEM(it).title;
            }
          }
        }
      }
      const sidebarChildren = () => [
        h(parts.Sidebar, {
          n: node({}, () => [
            sbSection('ark-sb-header')(node({}, () => [txt(o.brand) ? shellBrand(o) : null, ...slot(n, 'sidebarHeaderBuilder')])),
            sbSection('ark-sb-content')(node({}, () => [
              ...nav.map((g) => sbSection('ark-sb-group')(node({}, () => [
                NAV_LABEL(g) ? h(SidebarGroupLabel, { n: node({ text: NAV_LABEL(g) }) }) : null,
                sbSection('ark-sb-menu')(node({}, () => NAV_ITEMS(g).map((raw) => {
                  const it = ITEM(raw);
                  return h('div', { class: 'ark-sb-menu-item' }, h(SidebarMenuButton, {
                    n: node({ value: it.id, icon: it.icon, text: it.title, badge: it.badge, disabled: it.disabled })
                  }));
                })))
              ]))),
              ...slot(n, 'sidebarContentBuilder')
            ])),
            sbSection('ark-sb-footer')(node({}, () => [o.user ? shellUser(o.user) : null, ...slot(n, 'sidebarFooterBuilder')]))
          ])
        }),
        h(SidebarInset, {
          n: node({}, () => [
            ...slot(n, 'titleBarBuilder'),
            h('div', { class: 'ark-shell-scroll' }, [
              o.showTopbar === false ? null : h('div', { class: 'ark-shell-topbar' }, h(parts.Topbar, {
                n: node({
                  title, subtitle: o.subtitle, actions: o.actions, onAction: o.onAction, search: o.search,
                  searchPlaceholder: o.searchPlaceholder, onSearch: o.onSearch, onSearchChange: o.onSearchChange,
                  leading: o.topbarLeading, translucent: o.topbarBlur !== false
                }, () => slot(n, 'topbarActionsBuilder'), { slots: { leadingBuilder: n.slots?.topbarLeadingBuilder, titleBuilder: n.slots?.topbarTitleBuilder } })
              })),
              ...slot(n, 'headerBuilder'),
              h('div', { class: 'ark-shell-content', style: { maxWidth: o.maxContentWidth > 0 ? `${o.maxContentWidth}px` : (o.maxContentWidth === 0 ? undefined : '1200px') } }, n.children()),
              ...slot(n, 'footerBuilder'),
              o.footerText !== undefined ? h('div', { class: 'ark-shell-footer' }, txt(o.footerText)) : null
            ])
          ])
        })
      ];
      const providerNode = node({
        variant: o.variant ?? 'sidebar', collapsible: o.collapsible ?? 'icon', side: o.side, sidebarWidth: o.sidebarWidth,
        minInsetWidth: o.minInsetWidth, closeOnSelect: o.closeOnSelect, layoutPolicy: o.layoutPolicy,
        onPresentationChange: o.onPresentationChange, onOpenMobileChange: o.onOpenMobileChange,
        open: o.open, defaultOpen: o.defaultOpen, onOpenChange: o.onOpenChange,
        value: value.value, onValueChange: (v) => setValue(v), onNavigate: o.onNavigate, tokens: o.tokens?.sidebar
      }, sidebarChildren, { style: n.style, events: n.events, binds: { open: n.binds.open } });
      return h(SidebarProvider, { n: providerNode });
    };
  });
}

// ------------------------------------------------------------------------------------------------ list / detail

const LD_KEY = Symbol('list-detail');

const ListDetail = def('SListDetail', (props) => {
  const [show, setShow] = useControlled(props, 'showDetail', 'defaultShowDetail', false, ['onShowDetailChange']);
  const { el, width } = useWidth();
  const st = reactive({ width: 0, wide: false, listPaneWidth: 0, showDetail: false, setShow });
  provide(LD_KEY, st);
  let lastWide = null;
  return () => {
    const n = props.n;
    const o = n.props;
    const listWidth = o.listWidth > 0 ? o.listWidth : 320;
    const input = { containerWidth: width.value, paneWidth: listWidth, minOtherWidth: o.minDetailWidth ?? 360 };
    const custom = typeof o.layoutPolicy === 'function' ? call(o.layoutPolicy, input) : undefined;
    st.width = width.value;
    st.wide = typeof custom === 'boolean' ? custom : listDetailWide(input.containerWidth, input.paneWidth, input.minOtherWidth);
    st.listPaneWidth = listPaneWidth(width.value, listWidth, st.wide);
    st.showDetail = !!show.value;
    if (lastWide !== st.wide && width.value > 0) {
      lastWide = st.wide;
      call(o.onWideChange, st.wide);
    }
    return h('div', {
      ref: el, class: ['ark-ld', st.wide ? 'wide' : 'narrow', st.showDetail && 'show-detail'],
      style: [{ height: blockHeight(n, 440) }, tokenVars('list-detail', o.tokens), n.style], ...n.events
    }, n.children());
  };
});

const ListPane = def('SListPane', (props) => {
  const st = inject(LD_KEY, null);
  return () => {
    const n = props.n;
    const wide = !!st?.wide;
    const onTop = st && !wide && st.showDetail;
    return h('div', {
      class: ['ark-ld-list', wide && 'wide', onTop && 'covered'],
      style: [{ width: wide && st.width > 0 ? `${st.listPaneWidth}px` : '100%' }, n.style], ...n.events
    }, n.children());
  };
});

function listDetailPane(reg) {
  return def('SListDetailPane', (props) => {
    const st = inject(LD_KEY, null);
    return () => {
      const n = props.n;
      const o = n.props;
      const wide = !!st?.wide;
      const showBack = o.showBack !== false;
      const header = (!wide && showBack) || o.title !== undefined ? h('div', { class: ['ark-ld-header', wide && 'wide'] }, [
        !wide && showBack ? ghostIcon(reg, 'arrow-left', o.backLabel ?? 'Back', () => {
          if (call(o.onBack) !== true) {
            st?.setShow(false);
          }
        }) : null,
        h('div', { class: 'ark-ld-title' }, txt(o.title)),
        ...slot(n, 'headerBuilder')
      ]) : null;
      const body = o.empty ? (slot(n, 'emptyBuilder').length ? slot(n, 'emptyBuilder') :
        [h('div', { class: 'ark-ld-empty' }, [icon('inbox', 24), h('span', 'Nothing selected')])]) : n.children();
      const left = wide ? `${(st?.listPaneWidth ?? 0) + 1}px` : '0';
      return h('div', {
        class: ['ark-ld-detail', wide ? 'wide' : 'narrow', !wide && st?.showDetail && 'shown'],
        style: [{ left }, n.style], 'aria-hidden': !wide && !st?.showDetail ? 'true' : undefined
      }, [header, h('div', { class: 'ark-ld-body' }, body)]);
    };
  });
}

// ------------------------------------------------------------------------------------------------ supporting pane

const SP_KEY = Symbol('supporting-pane');

const SupportingPane = def('SSupportingPane', (props) => {
  const [open, setOpen] = useControlled(props, 'open', 'defaultOpen', false, ['onOpenChange']);
  const { el, width } = useWidth();
  const st = reactive({ width: 0, wide: false, mode: 'below', paneWidth: 320, gap: 24, open: false, setOpen, inSheet: false });
  provide(SP_KEY, st);
  let lastWide = null;
  return () => {
    const n = props.n;
    const o = n.props;
    st.paneWidth = o.paneWidth > 0 ? o.paneWidth : 320;
    st.mode = en(o.compactMode, 'below');
    st.width = width.value;
    const input = { containerWidth: width.value, paneWidth: st.paneWidth, minOtherWidth: o.minMainWidth ?? 480 };
    const custom = typeof o.layoutPolicy === 'function' ? call(o.layoutPolicy, input) : undefined;
    st.wide = typeof custom === 'boolean' ? custom : supportingWide(input.containerWidth, input.paneWidth, input.minOtherWidth);
    st.inSheet = !st.wide && st.mode === 'sheet';
    st.open = !!open.value;
    if (lastWide !== st.wide && width.value > 0) {
      lastWide = st.wide;
      call(o.onWideChange, st.wide);
    }
    return h('div', {
      ref: el, class: ['ark-sp', st.wide ? 'wide' : 'narrow'],
      style: [tokenVars('supporting-pane', o.tokens), n.style], ...n.events
    }, n.children());
  };
});

const SupportingMain = def('SSupportingPaneMain', (props) => {
  const st = inject(SP_KEY, null);
  return () => {
    const n = props.n;
    const w = st && st.wide && st.width > 0 ? `${Math.max(0, st.width - st.paneWidth)}px` : '100%';
    return h('div', { class: 'ark-sp-main', style: [{ width: w }, n.style], ...n.events }, n.children());
  };
});

function supportingAside(reg) {
  return def('SSupportingPaneAside', (props) => {
    const st = inject(SP_KEY, null);
    const themeClass = inject('arkThemeClass', ref('ark-theme'));
    const themeStyle = inject('arkThemeStyle', ref({}));
    return () => {
      const n = props.n;
      const o = n.props;
      const heading = o.title !== undefined ? h('div', { class: 'ark-sp-title' }, txt(o.title)) : null;
      if (st?.inSheet) {
        if (!st.open) {
          return null;
        }
        return h(Teleport, { to: 'body' }, h('div', { class: [themeClass.value, 'ark-modal-layer', 'ark-sp-sheet-layer'], style: themeStyle.value }, [
          h('div', { class: 'ark-modal-backdrop', onClick: () => st.setOpen(false) }),
          h('div', { class: 'ark-sp-sheet', role: 'dialog' }, [
            h('div', { class: 'ark-sp-handle' }),
            h('div', { class: 'ark-sp-sheet-head' }, [h('div', { class: 'ark-sp-sheet-title' }, heading), ghostIcon(reg, 'x', 'Close', () => st.setOpen(false))]),
            h('div', { class: 'ark-sp-sheet-body' }, n.children())
          ])
        ]));
      }
      const wide = !!st?.wide;
      return h('aside', {
        class: ['ark-sp-aside', wide ? 'wide' : 'below'],
        style: [{ width: wide && st.width > 0 ? `${st.paneWidth}px` : '100%' }, n.style], ...n.events
      }, [heading, ...n.children()]);
    };
  });
}

function supportingTrigger(reg) {
  return def('SSupportingPaneTrigger', (props) => {
    const st = inject(SP_KEY, null);
    return () => {
      if (!st?.inSheet) {
        return null;
      }
      const o = props.n.props;
      return reg.SButton(node({ variant: 'outline', sizing: 'sm', icon: o.icon ?? 'panel-right', text: o.text ?? 'Details' }, () => [],
        { style: props.n.style, events: { onClick: () => st.setOpen(true) } }));
    };
  });
}

// ------------------------------------------------------------------------------------------------ dashboard

const DASH_KEY = Symbol('dashboard');

const DashboardGrid = def('SDashboardGrid', (props) => {
  const { el, width } = useWidth();
  const cols = ref(1);
  provide(DASH_KEY, cols);
  return () => {
    const n = props.n;
    const o = n.props;
    const min = o.minTileWidth ?? 240;
    const gap = o.gap ?? 16;
    const W = width.value;
    let c = W > 0 ? Math.max(1, Math.floor((W + gap) / (min + gap))) : 0;
    if (o.maxColumns > 0 && c > 0) {
      c = Math.min(c, o.maxColumns);
    }
    cols.value = c || 1;
    const template = c > 0 ? `repeat(${c}, minmax(0, 1fr))` : `repeat(auto-fill, minmax(min(${min}px, 100%), 1fr))`;
    return h('div', { class: 'ark-dash', style: n.style, ...n.events }, [
      o.title !== undefined ? h('div', { class: 'ark-dash-head' }, [
        h('div', { class: 'ark-dash-titles' }, [
          h('div', { class: 'ark-dash-title' }, txt(o.title)),
          o.description !== undefined ? h('div', { class: 'ark-dash-description' }, txt(o.description)) : null
        ]),
        ...slot(n, 'actionsBuilder')
      ]) : null,
      h('div', { ref: el, class: 'ark-dash-grid', style: { gridTemplateColumns: template, gap: `${gap}px` } }, n.children())
    ]);
  };
});

const DashboardTile = def('SDashboardTile', (props) => {
  const cols = inject(DASH_KEY, ref(1));
  return () => {
    const n = props.n;
    const o = n.props;
    const span = o.full ? '1 / -1' : (o.span > 1 ? `span ${Math.min(o.span, cols.value)}` : undefined);
    const trend = en(o.trend, 'none');
    const variant = o.variant || 'default';
    return h('div', { class: 'ark-dash-cell', style: { gridColumn: span } }, h('div', {
      class: ['ark-card', `ark-card-${variant}`, 'ark-tile'], style: [tokenVars('card', o.tokens, variant), n.style], ...n.events
    }, h('div', { class: 'ark-card-content ark-tile-content' }, [
      o.title !== undefined || o.icon !== undefined ? h('div', { class: 'ark-tile-head' }, [
        h('span', { class: 'ark-tile-title' }, txt(o.title)), o.icon ? h('span', { class: 'ark-tile-icon' }, icon(o.icon, 16)) : null
      ]) : null,
      o.value !== undefined ? h('div', { class: 'ark-tile-value' }, txt(o.value)) : null,
      o.delta !== undefined ? h('div', { class: 'ark-tile-delta' }, [
        trend !== 'none' ? h('span', { style: { color: trend === 'down' ? 'var(--destructive)' : 'var(--muted-foreground)', display: 'inline-flex' } },
          icon(trend === 'up' ? 'trending-up' : 'trending-down', 14)) : null,
        txt(o.delta)
      ]) : null,
      ...n.children()
    ])));
  };
});

// ------------------------------------------------------------------------------------------------ registry

/** Block entries for the component registry; `reg` gives access to SButton / SInput / SAvatar. */
export function blocks(reg) {
  const Topbar = topbar(reg);
  const parts = { Sidebar, Topbar };
  return {
    SSidebarProvider: C(SidebarProvider),
    SSidebar: C(Sidebar),
    SSidebarHeader: sbSection('ark-sb-header'),
    SSidebarFooter: sbSection('ark-sb-footer'),
    SSidebarContent: sbSection('ark-sb-content'),
    SSidebarGroup: sbSection('ark-sb-group'),
    SSidebarGroupContent: sbSection('ark-sb-group-content'),
    SSidebarGroupLabel: C(SidebarGroupLabel),
    SSidebarMenu: sbSection('ark-sb-menu'),
    SSidebarMenuItem: sbSection('ark-sb-menu-item'),
    SSidebarMenuButton: C(SidebarMenuButton),
    SSidebarSeparator: (n) => h('div', { class: 'ark-sb-separator', style: n.style }),
    SSidebarTrigger: C(sidebarTrigger(reg)),
    SSidebarInset: C(SidebarInset),
    STopbar: C(Topbar),
    SAppShell: C(appShell(reg, parts)),
    SListDetail: C(ListDetail),
    SListPane: C(ListPane),
    SListDetailPane: C(listDetailPane(reg)),
    SSupportingPane: C(SupportingPane),
    SSupportingPaneMain: C(SupportingMain),
    SSupportingPaneAside: C(supportingAside(reg)),
    SSupportingPaneTrigger: C(supportingTrigger(reg)),
    SDashboardGrid: C(DashboardGrid),
    SDashboardTile: C(DashboardTile)
  };
}

export { node, len };
