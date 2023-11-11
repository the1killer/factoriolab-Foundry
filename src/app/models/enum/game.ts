import { SelectItem } from 'primeng/api';

export enum Game {
  Factorio = 'Factorio',
  CaptainOfIndustry = 'CaptainOfIndustry',
  DysonSphereProgram = 'DysonSphereProgram',
  Satisfactory = 'Satisfactory',
  Foundry = 'Foundry',
}

export const gameOptions: SelectItem<Game>[] = [
  { value: Game.Factorio, label: 'options.game.factorio' },
  { value: Game.DysonSphereProgram, label: 'options.game.dysonSphereProgram' },
  { value: Game.Satisfactory, label: 'options.game.satisfactory' },
  { value: Game.CaptainOfIndustry, label: 'options.game.captainOfIndustry' },
  { value: Game.Foundry, label: 'options.game.foundry' },
];
