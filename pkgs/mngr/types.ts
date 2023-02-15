export interface Package {
  name: string;
  lastUpdated: number;
  main: string;
  deps: string[];
  files: string[];
}
