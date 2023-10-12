/**
 * Serves the Lua packages for mngr.
 *
 * @module
 */

import { fs, oak, path } from './deps.ts';

/** The root dir path that contains the packages. */
const ROOT_PACKAGES_DIR_PATH = 'pkgs/';
/** Valid package file extensions. */
const PACKAGE_FILE_EXTS = ['.lua'];

const router = new oak.Router();

router
  /// Respond with newline-separated package names.
  .get('/', async (context) => {
    const names: string[] = [];

    for await (
      const entry of fs.walk(ROOT_PACKAGES_DIR_PATH, {
        maxDepth: 1,
        includeFiles: false,
        followSymlinks: true,
      })
    ) {
      if (entry.path !== ROOT_PACKAGES_DIR_PATH) {
        names.push(entry.name);
      }
    }

    context.response.body = names.join('\n');
  })
  /// Respond with newline-separated package files.
  .get('/:package', async (context) => {
    const dirPath = path.join(ROOT_PACKAGES_DIR_PATH, context.params.package);

    if (await fs.exists(dirPath, { isDirectory: true, isReadable: true })) {
      const names: string[] = [];

      for await (
        const entry of fs.walk(dirPath, {
          maxDepth: 1,
          includeDirs: false,
          followSymlinks: true,
          exts: PACKAGE_FILE_EXTS,
        })
      ) {
        names.push(entry.name);
      }

      context.response.body = names.join('\n');
    } else {
      context.response.status = oak.Status.NotFound;
    }
  })
  /// Respond with the content of the package file.
  .get('/:package/:file', async (context) => {
    const dirPath = path.join(ROOT_PACKAGES_DIR_PATH, context.params.package);
    const filePath = path.join(dirPath, context.params.file);

    if (
      PACKAGE_FILE_EXTS.includes(path.extname(filePath)) &&
      await fs.exists(dirPath, { isDirectory: true, isReadable: true }) &&
      await fs.exists(filePath, { isFile: true, isReadable: true })
    ) {
      context.response.body = await Deno.readTextFile('server/prepend.lua') +
        '\n' + await Deno.readTextFile(filePath);
    } else {
      context.response.status = oak.Status.NotFound;
    }
  });

const app = new oak.Application();

app.use(router.routes());
app.use(router.allowedMethods());

await app.listen({ port: 3000 });
