import { Pipe, PipeTransform } from '@angular/core';

import { Rational } from '~/models';
import { DisplayService } from '~/services';

/** Used in tooltips / data pages to format strings describing module effects */
@Pipe({ name: 'bonusPercent' })
export class BonusPercentPipe implements PipeTransform {
  constructor(private displaySvc: DisplayService) {}

  transform(value: Rational): string {
    return this.displaySvc.toBonusPercent(value);
  }
}
