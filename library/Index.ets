export const SPARKUI_VERSION: string = '0.1.0';

// core
export { SparkUI } from './src/main/ets/core/SparkUI';
export { SparkProvider } from './src/main/ets/core/SparkProvider';
export { sparkEmptyBuilder } from './src/main/ets/core/Builders';

// theme
export { SparkColor, Rgba, ColorParseResult } from './src/main/ets/theme/color/SparkColor';
export { SparkColors, SPARK_COLOR_TOKENS } from './src/main/ets/theme/tokens/SparkColors';
export {
  SparkTheme, SparkThemeMode, SparkShadow, SparkShadows, SparkTypography, SparkMotion
} from './src/main/ets/theme/tokens/SparkTheme';
export { ThemeDiagnostic, ThemeDiagnosticSeverity, ThemeSource, ThemeVar } from './src/main/ets/theme/css/ThemeSource';
export { ThemeCssParser } from './src/main/ets/theme/css/ThemeCssParser';
export { ThemeResolver, REM_VP } from './src/main/ets/theme/css/ThemeResolver';
export {
  SparkPresetName, SPARK_PRESETS, presetCss, SparkAccentName, SPARK_ACCENTS, accentCss
} from './src/main/ets/theme/presets/Presets';
export { SparkThemeController, ThemeLoadResult, ThemeLoadOptions } from './src/main/ets/theme/SparkThemeController';
export { SystemThemeBridge } from './src/main/ets/theme/SystemThemeBridge';

// layout
export {
  SparkLayoutContext, SparkEnvironment, SparkLayoutThresholds, SparkSizeClassName, SparkPosture, SparkModality,
  SparkWindowMode, SparkAdaptive, SparkRect, SparkInsets, sizeClassIndex
} from './src/main/ets/layout/SparkLayoutContext';
export { SparkLayoutMonitor } from './src/main/ets/layout/SparkLayoutMonitor';
export { SparkContainer, resolveSparkLayout, SPARK_LAYOUT_KEY } from './src/main/ets/layout/SparkContainer';

// primitives
export { SparkNoopModifier, sparkColorMetrics, sparkFocusRing, SparkTapBlocker } from './src/main/ets/core/SparkModifier';
export { SparkContext } from './src/main/ets/core/SparkContext';
export { SparkInteraction } from './src/main/ets/core/SparkInteraction';

// icons
export { SIcon } from './src/main/ets/icons/SIcon';
export { SparkIcons } from './src/main/ets/icons/SparkIcons';
export { SparkIconData, scalePathCommands } from './src/main/ets/icons/SparkIconData';

// components
export { SButton } from './src/main/ets/components/button/SButton';
export {
  ButtonVariants, ButtonStyle, ButtonStyleModifier, ButtonVariant, ButtonSize
} from './src/main/ets/components/button/ButtonVariants';

// overlay base
export {
  Placement, PlacementRect, PlacementRequest, PlacementResult, SparkSide, SparkAlign
} from './src/main/ets/primitives/overlay/Placement';
export {
  SparkOverlayScope, SparkOverlayService, SparkPresentation, SparkDismissReason, SparkDismissHandler
} from './src/main/ets/primitives/overlay/SparkOverlay';
export { SparkOverlayHost, openSparkOverlay, closeSparkOverlay } from './src/main/ets/primitives/overlay/SparkOverlayHost';
export { SparkDisclosure, sparkTriggerKey } from './src/main/ets/primitives/SparkDisclosure';

export {
  SDialog, SDialogTrigger, SDialogContent, SDialogHeader, SDialogFooter, SDialogTitle, SDialogDescription, SDialogClose
} from './src/main/ets/components/dialog/SDialog';
export { SPopover, SPopoverTrigger, SPopoverContent, SPopoverClose } from './src/main/ets/components/popover/SPopover';
export { SCodeBlock, CodePalette } from './src/main/ets/components/code/SCodeBlock';
export { CodeHighlighter, CodeLanguage, CodeToken, CodeTokenKind } from './src/main/ets/components/code/CodeHighlighter';
export {
  SSheet, SSheetTrigger, SSheetContent, SSheetHeader, SSheetFooter, SSheetTitle, SSheetDescription, SSheetClose,
  SheetSide
} from './src/main/ets/components/sheet/SSheet';

// breakpoint-free layout primitives
export {
  SPage, SStack, SRow, SFlow, SGrid, SGridItem, SColumns, SColumn, SparkGridState, SparkColumnsState, sparkGridColumns,
  sparkGutter
} from './src/main/ets/layout/SparkLayouts';

export {
  SCard, SCardHeader, SCardTitle, SCardDescription, SCardAction, SCardContent, SCardFooter, SparkCardState
} from './src/main/ets/components/card/SCard';

// overlay components
export { OverlayBinding, OverlayConfigurator, SparkActivation } from './src/main/ets/primitives/overlay/OverlayBinding';
export { MenuRow, MenuSeparator, MenuLabel, MenuIndicator, MenuItemVariant } from './src/main/ets/primitives/menu/MenuRow';
export { SPARK_DIALOG_KEY } from './src/main/ets/components/dialog/SDialog';
export {
  SAlertDialog, SAlertDialogTrigger, SAlertDialogContent, SAlertDialogAction, SAlertDialogCancel
} from './src/main/ets/components/alert-dialog/SAlertDialog';
export { STooltip, STooltipTrigger, STooltipContent } from './src/main/ets/components/tooltip/STooltip';
export {
  SDropdownMenu, SDropdownMenuTrigger, SDropdownMenuContent, SDropdownMenuItem, SDropdownMenuCheckboxItem,
  SDropdownMenuRadioGroup, SDropdownMenuRadioItem, SDropdownMenuLabel, SDropdownMenuSeparator, SDropdownMenuGroup,
  sparkUseSheet
} from './src/main/ets/components/dropdown-menu/SDropdownMenu';
export {
  SSelect, SSelectTrigger, SSelectContent, SSelectItem, SSelectLabel, SSelectSeparator, SSelectGroup,
  SparkSelectOption, SparkSelectState
} from './src/main/ets/components/select/SSelect';
export {
  SparkToast, SparkToaster, SparkToastItem, SparkToastAction, SparkToastOptions, SparkToastVariant, SToastStack, toast
} from './src/main/ets/components/toast/SparkToast';

// forms
export { SparkPressModifier } from './src/main/ets/core/SparkPress';
export { SLabel } from './src/main/ets/components/label/SLabel';
export {
  SField, SFieldLabel, SFieldContent, SFieldDescription, SFieldError, SFieldGroup, SFieldSet, SFieldLegend,
  SFieldSeparator, SparkFieldState, FieldOrientation, FieldLegendVariant, resolveSparkField, sparkFieldGrows,
  FIELD_RESPONSIVE_MIN_WIDTH
} from './src/main/ets/components/field/SField';
export { SInput, InputKind, InputColors, sparkInputColors, sparkNoFocusBox } from './src/main/ets/components/input/SInput';
export { STextarea } from './src/main/ets/components/textarea/STextarea';
export { SCheckbox } from './src/main/ets/components/checkbox/SCheckbox';
export { SSwitch } from './src/main/ets/components/switch/SSwitch';
export {
  SRadioGroup, SRadioGroupItem, SparkRadioGroupState, RadioGroupOrientation
} from './src/main/ets/components/radio-group/SRadioGroup';
export { SSlider, sparkSnapSlider } from './src/main/ets/components/slider/SSlider';
export { SProgress } from './src/main/ets/components/progress/SProgress';

// display
export { SBadge, BadgeVariant, BadgeVariants, BadgeStyle } from './src/main/ets/components/badge/SBadge';
export { SSeparator, SeparatorOrientation } from './src/main/ets/components/separator/SSeparator';
export { SSkeleton } from './src/main/ets/components/skeleton/SSkeleton';
export { SSpinner } from './src/main/ets/components/spinner/SSpinner';
export { SKbd, SKbdGroup } from './src/main/ets/components/kbd/SKbd';
export { SAvatar } from './src/main/ets/components/avatar/SAvatar';
export { SAlert, SAlertTitle, SAlertDescription, AlertVariant, SparkAlertState } from './src/main/ets/components/alert/SAlert';
export {
  SEmpty, SEmptyHeader, SEmptyMedia, SEmptyTitle, SEmptyDescription, SEmptyContent, EmptyMediaVariant
} from './src/main/ets/components/empty/SEmpty';
export {
  SItemGroup, SItem, SItemSeparator, SItemMedia, SItemContent, SItemTitle, SItemDescription, SItemActions,
  ItemVariant, ItemSize, ItemMediaVariant, SparkItemState, SparkItemGroupState
} from './src/main/ets/components/item/SItem';
export {
  SH1, SH2, SH3, SH4, SP, SLead, SLarge, SSmall, SMuted, SBlockquote, SInlineCode, SList
} from './src/main/ets/components/typography/STypography';
export { SAspectRatio } from './src/main/ets/components/aspect-ratio/SAspectRatio';

// navigation & disclosure
export { SparkSelection } from './src/main/ets/primitives/SparkSelection';
export { SparkCollapse } from './src/main/ets/primitives/SparkCollapse';
export { SparkRowPressModifier } from './src/main/ets/primitives/SparkPressModifier';
export { STabs, STabsList, STabsTrigger, STabsContent, SparkTabsState } from './src/main/ets/components/tabs/STabs';
export {
  SAccordion, SAccordionItem, SAccordionTrigger, SAccordionContent, SparkAccordionItemState, AccordionType
} from './src/main/ets/components/accordion/SAccordion';
export {
  SCollapsible, SCollapsibleTrigger, SCollapsibleContent, SparkCollapsibleState
} from './src/main/ets/components/collapsible/SCollapsible';
export {
  ToggleVariants, ToggleStyle, ToggleStyleModifier, ToggleVariant, ToggleSize, ToggleJoin
} from './src/main/ets/components/toggle/ToggleVariants';
export { SToggle } from './src/main/ets/components/toggle/SToggle';
export {
  SToggleGroup, SToggleGroupItem, SparkToggleGroupState, ToggleGroupType
} from './src/main/ets/components/toggle-group/SToggleGroup';
export {
  SButtonGroup, SButtonGroupSeparator, SparkButtonGroupState, ButtonGroupOrientation
} from './src/main/ets/components/button-group/SButtonGroup';
export {
  SBreadcrumb, SBreadcrumbList, SBreadcrumbItem, SBreadcrumbLink, SBreadcrumbPage, SBreadcrumbSeparator,
  SBreadcrumbEllipsis
} from './src/main/ets/components/breadcrumb/SBreadcrumb';
export { sparkPaginationRange, SPARK_PAGINATION_ELLIPSIS } from './src/main/ets/components/pagination/PaginationRange';
export { SPagination } from './src/main/ets/components/pagination/SPagination';
export { SScrollArea, ScrollAreaOrientation } from './src/main/ets/components/scroll-area/SScrollArea';

// motion
export { SparkAnim, SparkSpeed, SparkMotionOptions } from './src/main/ets/core/SparkAnim';
export { SparkMotionOverride } from './src/main/ets/theme/tokens/SparkTheme';
export { sparkPaginationSiblings } from './src/main/ets/components/pagination/PaginationRange';
