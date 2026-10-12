import { sparkEmptyBuilder } from '../../core/Builders';
import { SparkContext } from '../../core/SparkContext';
import { SparkActivation } from '../../primitives/overlay/OverlayBinding';
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
 *       SAlertDialogAction({ text: 'Continue' }).onClick(() => this.deleteAccount())
 *     }
 *   }
 * }
 * ```
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
  @Local opened: boolean = false;

  aboutToAppear(): void {
    this.opened = this.open ?? this.defaultOpen;
  }

  @Monitor('open')
  syncOpen(): void {
    if (this.open !== undefined) {
      this.opened = this.open;
    }
  }

  build() {
    SDialog({
      open: this.open !== undefined ? this.opened : undefined,
      defaultOpen: this.defaultOpen,
      $open: (v: boolean) => {
        this.opened = v;
        this.$open(v);
      },
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

/** Shared logic of Action / Cancel: render a button and close the dialog in parallel with `.onClick()`. */
@ComponentV2
struct AlertDialogButton {
  @Param text: ResourceStr = '';
  @Param variant: ButtonVariant = 'default';
  @Param disabled: boolean = false;
  @Local ctx: SparkDisclosure | undefined = undefined;

  onDidBuild(): void {
    SparkContext.whenAttached(this.getUIContext(), this.getUniqueId(), () => this.sparkResolve());
  }

  private sparkResolve(): void {
    if (this.ctx === undefined) {
      this.ctx = SparkContext.resolve<SparkDisclosure>(this.getUIContext(), this.getUniqueId(), SPARK_DIALOG_KEY);
    }
  }

  private activation: SparkActivation = new SparkActivation();

  build() {
    Stack() {
      SButton({ text: this.text, variant: this.variant, disabled: this.disabled })
    }
    .onTouch((e: TouchEvent) => this.activation.touch(e, this.disabled, () => this.ctx?.setOpen(false)))
  }
}

/** Primary action; closes the dialog. Attach the work with `.onClick()`. */
@ComponentV2
export struct SAlertDialogAction {
  @Param text: ResourceStr = 'Continue';
  /** e.g. 'destructive' for dangerous actions */
  @Param variant: ButtonVariant = 'default';
  @Param disabled: boolean = false;

  build() {
    AlertDialogButton({ text: this.text, variant: this.variant, disabled: this.disabled })
  }
}

/** Cancel button (outline); closes the dialog. */
@ComponentV2
export struct SAlertDialogCancel {
  @Param text: ResourceStr = 'Cancel';

  build() {
    AlertDialogButton({ text: this.text, variant: 'outline' })
  }
}
