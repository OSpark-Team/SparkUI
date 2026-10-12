export type StepperOrientation = 'horizontal' | 'vertical' | 'responsive';
export type StepperItemState = 'completed' | 'active' | 'inactive';

/** Minimum width (vp) of one horizontal step; a responsive stepper stacks vertically below `count × this`. */
export const STEPPER_MIN_ITEM_WIDTH: number = 140;

/** Horizontal layout? `responsive` is horizontal when every step gets at least 140vp. */
export function sparkStepperHorizontal(orientation: StepperOrientation, width: number, count: number): boolean {
  if (orientation === 'horizontal') {
    return true;
  }
  if (orientation === 'vertical') {
    return false;
  }
  if (width <= 0) {
    return true;
  }
  return width >= Math.max(1, count) * STEPPER_MIN_ITEM_WIDTH;
}

/** State of `step` when `current` is the active step. */
export function sparkStepState(step: number, current: number): StepperItemState {
  if (step < current) {
    return 'completed';
  }
  return step === current ? 'active' : 'inactive';
}

/** Can the user jump to `step`? Linear steppers allow earlier steps and the next one only. */
export function sparkStepReachable(step: number, current: number, linear: boolean): boolean {
  return !linear || step <= current + 1;
}
