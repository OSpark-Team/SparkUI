import { SparkInteraction } from '../../core/SparkInteraction';
import { sparkFocusRing, SparkTapBlocker } from '../../core/SparkModifier';
import { SparkUI } from '../../core/SparkUI';
import { SIcon } from '../../icons/SIcon';
import { SparkAdaptive, SparkLayoutContext } from '../../layout/SparkLayoutContext';
import { OverlayBinding } from '../../primitives/overlay/OverlayBinding';
import { SparkOverlayScope } from '../../primitives/overlay/SparkOverlay';
import { SparkDisclosure, sparkTriggerKey } from '../../primitives/SparkDisclosure';
import { SparkColor } from '../../theme/color/SparkColor';
import { SparkTheme } from '../../theme/tokens/SparkTheme';
import { SCommand, SCommandEmpty, SCommandGroup, SCommandInput, SCommandItem, SCommandList } from '../command/SCommand';
import { sparkUseSheet } from '../dropdown-menu/SDropdownMenu';
import { SparkSelectOption } from '../select/SSelect';

/** Options split at each `group` heading (SparkSelectOption.group starts a new group). */
class ComboGroup {
  key: string;
  heading: string | undefined;
  options: SparkSelectOption[] = [];

  constructor(key: string, heading: string | undefined) {
    this.key = key;
    this.heading = heading;
  }
}

/**
 * shadcn-vue `Combobox` (Popover + Command): an outline button showing the selected label and a
 * chevrons-up-down icon; opens a searchable list with a check mark on the selected option.
 *
 * ```
 * SCombobox({
 *   value: this.framework!!,
 *   options: FRAMEWORKS,                       // SparkSelectOption[] (shared with SSelect)
 *   placeholder: 'Select framework…',
 *   searchPlaceholder: 'Search framework…',
 *   emptyText: 'No framework found.'
 * })
 * ```
 * Anchored below the trigger (as wide as the trigger, at least 200vp) on pointer / wide screens; a bottom
 * sheet on compact touch screens. Selecting the current option again clears it (shadcn behaviour) unless
 * `deselectable: false`.
 */
@ComponentV2
export struct SCombobox {
  @Param value: string | undefined = undefined;
  @Event $value: (v: string) => void = () => {
  };
  @Param defaultValue: string = '';
  @Event onValueChange: (v: string) => void = () => {
  };
  @Param options: SparkSelectOption[] = [];
  @Param placeholder: ResourceStr = 'Select option…';
  @Param searchPlaceholder: ResourceStr = 'Search…';
  @Param emptyText: ResourceStr = 'No results found.';
  /** trigger width (shadcn demo: w-[200px]); '100%' to fill the parent */
  @Param triggerWidth: Length = 200;
  @Param disabled: boolean = false;
  @Param deselectable: boolean = true;
  @Param adaptive: SparkAdaptive = 'auto';
  @Consumer('sparkTheme') theme: SparkTheme = SparkUI.theme;
  @Consumer('sparkLayout') layout: SparkLayoutContext = SparkUI.layout.root;
  @Local current: string = '';
  @Local disclosure: SparkDisclosure = new SparkDisclosure();
  @Local sheet: boolean = false;
  @Local anchorWidth: number = 200;
  @Local ix: SparkInteraction = new SparkInteraction();
  private binding: OverlayBinding = new OverlayBinding();

  aboutToAppear(): void {
    this.current = this.value ?? this.defaultValue;
    this.disclosure.triggerKey = sparkTriggerKey(this.getUniqueId());
    this.disclosure.triggerUniqueId = this.getUniqueId();
    this.binding.attach(this.getUIContext(), this.disclosure, (scope: SparkOverlayScope) => {
      this.sheet = sparkUseSheet(this.adaptive);
      this.disclosure.placement = this.sheet ? 'sheet' : 'anchored';
      const anchor = this.disclosure.anchorRect(this.getUIContext());
      this.anchorWidth = anchor !== undefined ? anchor.width : 200;
      scope.presentation = this.sheet ? 'sheet-bottom' : 'anchored';
      scope.motionKey = 'popover';
      scope.modal = this.sheet;
      scope.dismissOnOutside = true;
      scope.anchor = anchor;
      scope.side = 'bottom';
      scope.alignment = 'start';
      scope.sideOffset = 4;
      scope.content = this.panel;
      scope.contextKey = '';
      scope.theme = this.theme;
      scope.layout = this.layout;
    });
  }

  aboutToDisappear(): void {
    this.binding.dispose();
  }

  @Monitor('value')
  sync(): void {
    if (this.value !== undefined) {
      this.current = this.value;
    }
  }

  @Computed
  get label(): string | undefined {
    const o = this.options.find((x: SparkSelectOption) => x.value === this.current);
    return o === undefined ? undefined : o.label;
  }

  @Computed
  get groups(): ComboGroup[] {
    const out: ComboGroup[] = [];
    this.options.forEach((o: SparkSelectOption, i: number) => {
      if (out.length === 0 || o.group !== undefined) {
        out.push(new ComboGroup(`${i}|${o.group ?? ''}`, o.group));
      }
      out[out.length - 1].options.push(o);
    });
    return out;
  }

  @Computed
  get blocker(): SparkTapBlocker {
    return new SparkTapBlocker(this.disabled);
  }

  private choose(v: string): void {
    const next = this.deselectable && v === this.current ? '' : v;
    if (this.value === undefined) {
      this.current = next;
    }
    this.$value(next);
    this.onValueChange(next);
    this.disclosure.setOpen(false);
  }

  @Styles
  normalStyle() {
    .backgroundColor(this.ix.hovered && !this.disabled ? this.theme.colors.accent :
      (this.theme.isDark ? SparkColor.alpha(this.theme.colors.input, 0.3) : this.theme.colors.background))
  }

  @Styles
  pressedStyle() {
    .backgroundColor(this.disabled ? this.theme.colors.background : this.theme.colors.accent)
  }

  @LocalBuilder
  panel() {
    Column() {
      if (this.sheet) {
        Row() {
          Column().width(40).height(4).borderRadius(2).backgroundColor(this.theme.colors.muted)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 8, bottom: 4 })
      }
      SCommand() {
        SCommandInput({ placeholder: this.searchPlaceholder, autoFocus: !this.sheet })
        SCommandList({ maxListHeight: this.sheet ? 360 : 300 }) {
          SCommandEmpty({ text: this.emptyText })
          ForEach(this.groups, (g: ComboGroup) => {
            SCommandGroup({ heading: g.heading }) {
              ForEach(g.options, (o: SparkSelectOption) => {
                SCommandItem({
                  value: o.value,
                  text: o.label,
                  disabled: o.disabled,
                  checked: this.current === o.value,
                  onSelect: (v: string) => this.choose(v)
                })
              }, (o: SparkSelectOption) => o.value)
            }
          }, (g: ComboGroup) => g.key)
        }
      }
    }
    // definite width (at least the trigger's): '100%' rows would otherwise resolve against the overlay layer
    .width(this.sheet ? '100%' : Math.max(this.anchorWidth, 200))
    .padding({ bottom: this.sheet ? this.layout.env.safeArea.bottom : 0 })
    .backgroundColor(this.theme.colors.popover)
    .border({
      width: this.sheet ? { top: 1 } : 1,
      color: this.theme.colors.border,
      radius: this.sheet ? { topLeft: this.theme.radiusXl, topRight: this.theme.radiusXl } : this.theme.radiusMd
    })
    .shadow(this.theme.shadows.md.toOptions())
    .clip(true)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    Row({ space: 8 }) {
      Text(this.label ?? this.placeholder)
        .layoutWeight(1)
        .fontSize(this.theme.text.sm)
        .fontWeight(this.theme.text.weightMedium)
        .fontColor(this.theme.colors.foreground)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      SIcon({ name: 'chevrons-up-down', sizing: 16, color: this.theme.colors.foreground })
        .opacity(0.5)
    }
    .id(sparkTriggerKey(this.getUniqueId()))
    .width(this.triggerWidth)
    .height(36)
    .padding({ left: 12, right: 12 })
    .border({
      width: 1,
      color: this.theme.isDark ? this.theme.colors.input : this.theme.colors.border,
      radius: this.theme.radiusMd
    })
    .shadow(this.theme.shadows.xs.toOptions())
    .stateStyles({ normal: this.normalStyle, pressed: this.pressedStyle })
    .opacity(this.disabled ? 0.5 : 1)
    .onHover((h: boolean) => this.ix.hover(this.getUIContext(), this.theme, h))
    .gestureModifier(this.blocker)
    .focusable(!this.disabled)
    .focusBox(sparkFocusRing(this.theme))
    .accessibilityText(this.label ?? '')
    .onClick(() => {
      if (!this.disabled) {
        this.disclosure.toggle();
      }
    })
  }
}
