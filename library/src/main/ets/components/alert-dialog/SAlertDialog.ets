import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { sparkIsEnterUp } from '../../primitives/menu/MenuRow';
import { SparkDisclosure } from '../../primitives/SparkDisclosure';
import { ButtonVariant } from '../button/ButtonVariants';
import { SButton } from '../button/SButton';
import { SDialog, SDialogContent, SDialogTrigger, SPARK_DIALOG_KEY } from '../dialog/SDialog';

/**
 * shadcn-vue `AlertDialog`: a modal dialog that interrupts the user and expects a response. Unlike Dialog it
 * has no close button and ignores backdrop taps; the back gesture / Esc still cancel.
 * Header, Title, Description and Footer are the Dialog parts (SDialogHeader … SDialogFooter).
 *
 * ```
 * SAlertDialog() {
 *   SAlertDialogTrigger() { SButton({ text: 'Delete account', variant: 'destructive' }) }
 *   SAlertDialogContent() {
 *     SDialogHeader() {
 *       SDialogTitle({ text: 'Are you absolutely sure?' })
 *       SDialogDescription({ text: 'This action cannot be undone.' })
 *     }
 *     SDialogFooter() {
 *       SAlertDialogCancel()
 *       SAlertDialogAction({ text: 'Continue', onAction: () => this.deleteAccount() })
 *     }
 *   }
 * }
 * ```
 * Controlled (`open: this.show!!` or `open` + `onOpenChange`): Action / Cancel / back only request closing;
 * the dialog closes when the parent's `open` flows back false (like SDialog), so the parent can refuse.
 */
@ComponentV2
export struct SAlertDialog {
  @Param open: boolean | undefined = undefined;
  @Event $open: (open: boolean) => void = () => {
  };
  @Param defaultOpen: boolean = false;
  @Event onOpenChange: (open: boolean) => void = () => {
  };
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    SDialog({
      open: this.open,
      defaultOpen: this.defaultOpen,
      $open: (v: boolean) => this.$open(v),
      onOpenChange: (v: boolean) => this.onOpenChange(v)
    }) {
      this.content()
    }
  }
}

@ComponentV2
export struct SAlertDialogTrigger {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    SDialogTrigger() {
      this.content()
    }
  }
}

/** Alert panel: no close button, backdrop taps ignored, Drawer on compact touch screens. */
@ComponentV2
export struct SAlertDialogContent {
  @BuilderParam content: () => void = sparkEmptyBuilder;

  build() {
    SDialogContent({ showCloseButton: false, dismissOnOutside: false }) {
      this.content()
    }
  }
}

/**
 * Shared logic of Action / Cancel: a button whose activation — tap, click, Enter (Space where the system routes
 * it), screen-reader activation — runs `onActivate` and then requests closing the dialog. The click lives on the
 * wrapping node (the button inside has no click of its own, so its taps reach it; while disabled the button's
 * tap blocker swallows them).
 */
@ComponentV2
struct AlertDialogButton {
  @Param text: ResourceStr = '';
  @Param variant: ButtonVariant = 'default';
  @Param disabled: boolean = false;
  @Event onActivate: () => void = () => {
  };
  @Local ctx: SparkDisclosure | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = SparkContext.resolve<SparkDisclosure>(this.getUIContext(), this.getUniqueId(), SPARK_DIALOG_KEY);
    }
  }

  private activate(): void {
    if (this.disabled) {
      return;
    }
    this.onActivate();
    this.ctx?.setOpen(false);
  }

  build() {
    Stack() {
      SButton({ text: this.text, variant: this.variant, disabled: this.disabled })
    }
    .onClick(() => this.activate())
    .onKeyEvent((e: KeyEvent) => {
      if (sparkIsEnterUp(e)) {
        this.activate();
      }
    })
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(typeof this.text === 'string' ? this.text : '')
    .accessibilityDescription(this.disabled ? 'disabled' : '')
  }
}

/**
 * Primary action; runs `onAction`, then closes the dialog (a controlled owner may refuse). Attach the work with
 * `onAction` — a `.onClick()` chained on this component does not fire (the button's own click takes it).
 */
@ComponentV2
export struct SAlertDialogAction {
  @Param text: ResourceStr = 'Continue';
  /** e.g. 'destructive' for dangerous actions */
  @Param variant: ButtonVariant = 'default';
  @Param disabled: boolean = false;
  @Event onAction: () => void = () => {
  };

  build() {
    AlertDialogButton({
      text: this.text,
      variant: this.variant,
      disabled: this.disabled,
      onActivate: () => this.onAction()
    })
  }
}

/** Cancel button (outline); runs `onCancel`, then closes the dialog. */
@ComponentV2
export struct SAlertDialogCancel {
  @Param text: ResourceStr = 'Cancel';
  @Event onCancel: () => void = () => {
  };

  build() {
    AlertDialogButton({ text: this.text, variant: 'outline', onActivate: () => this.onCancel() })
  }
}
