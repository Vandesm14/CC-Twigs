export interface Package {
  /** The name of the package */
  name: string;

  /** The main file (shell can run it as `$ <pkg>`) */
  main: string;

  /** The dependencies of the package */
  deps: string[];

  /** The files included in the package */
  files: string[];

  /** The checksums for each file */
  checksums: Record<string, string>;

  /** Mappings between files and their corresponding commands */
  bin: Record<string, string>;
}
