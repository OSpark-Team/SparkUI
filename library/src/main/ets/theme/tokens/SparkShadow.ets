/** A single drop shadow. ArkUI renders one shadow per component, so CSS multi-shadows keep the first layer. */
export class SparkShadow {
  offsetX: number = 0;
  offsetY: number = 0;
  /** blur radius in vp */
  radius: number = 0;
  color: string = '#00000000';

  constructor(offsetX: number, offsetY: number, radius: number, color: string) {
    this.offsetX = offsetX;
    this.offsetY = offsetY;
    this.radius = radius;
    this.color = color;
  }

  /** `none`: no visible shadow. */
  static none(): SparkShadow {
    return new SparkShadow(0, 0, 0, '#00000000');
  }

  /** true when the shadow draws nothing (zero blur and offset, or a fully transparent colour). */
  get isNone(): boolean {
    return (this.radius === 0 && this.offsetX === 0 && this.offsetY === 0) || this.color.substring(0, 3) === '#00';
  }

  toOptions(): ShadowOptions {
    return {
      radius: this.radius,
      color: this.color,
      offsetX: this.offsetX,
      offsetY: this.offsetY
    };
  }
}
