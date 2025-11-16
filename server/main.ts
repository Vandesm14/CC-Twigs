/**
 * Serves the Lua packages for mngr.
 *
 * @module
 */

import * as fs from '@std/fs';
import * as path from '@std/path';
import * as cli from '@std/cli';
import * as oak from '@oak/oak';

/** The root dir path that contains the packages. */
const ROOT_PACKAGES_DIR_PATH = 'pkgs/';
/** Valid package file extensions. */
const PACKAGE_FILE_EXTS = ['.lua'];
/** A RegExp that matches `require("...")`. */
const REQUIRE_REGEXP = /(?<=require\(("|')).*(?=("|')\))/g;

const args = cli.parseArgs(Deno.args);
const port = typeof args.port === 'number' ? args.port : 3000;
const host = typeof args.host === 'string' ? args.host : 'localhost';

const router = new oak.Router();

router
  /// Respond with newline-separated package names.
  .get('/', async (context) => {
    const names = await getPackages();
    context.response.body = names.join('\n');
  })
  /// Respond with newline-separated package files.
  .get('/:package', async (context) => {
    const names = await getPackageFiles(context.params.package);

    if (typeof names !== 'undefined') {
      context.response.body = names.join('\n');
    } else {
      context.response.status = oak.Status.NotFound;
    }
  })
  /// Respond with the content of the package file.
  .get('/:package/:file', async (context) => {
    const content = await readPackageFileContent(
      context.params.package,
      context.params.file
    );

    if (typeof content !== 'undefined') {
      context.response.body = content;
    } else {
      context.response.status = oak.Status.NotFound;
    }
  })
  /// Respond with newline-separated package dependencies of the package file.
  .get('/:package/:file/deps', async (context) => {
    const content = await readPackageFileContent(
      context.params.package,
      context.params.file
    );
    const packages = await getPackages();

    if (typeof content === 'undefined' || typeof packages === 'undefined') {
      context.response.status = oak.Status.NotFound;
      return;
    }

    const matches = [...content.matchAll(REQUIRE_REGEXP)];
    const matchesDedupe = [...new Set(matches.map((m) => m[0]))];
    const matchesDedupeSplit = matchesDedupe.map((m) => m.split('.'));

    for (let i = matchesDedupeSplit.length - 1; i >= 0; i--) {
      const [package_, file] = matchesDedupeSplit[i];

      if (
        typeof package_ !== 'undefined' &&
        typeof file !== 'undefined' &&
        package_ !== context.params.package &&
        packages.includes(package_)
      ) {
        const files = await getPackageFiles(package_);

        if (typeof files !== 'undefined' && files.includes(file + '.lua')) {
          continue;
        }
      }

      matchesDedupeSplit.splice(i, 1);
    }

    context.response.body = matchesDedupeSplit.map(([p, _]) => p).join('\n');
  })
  /// Upload a file to the server.
  .post('/upload/:computerid/:path*', async (context) => {
    const computerId = context.params.computerid;
    const filePath = context.params.path;

    if (!computerId || !filePath) {
      context.response.status = oak.Status.BadRequest;
      context.response.body = 'Missing computer ID or file path';
      return;
    }

    try {
      const body = context.request.body;
      const fileContent = await body.text();

      const uploadDir = path.join('uploads', computerId);
      await fs.ensureDir(uploadDir);

      const fullPath = path.join(uploadDir, filePath);
      const fileDir = path.dirname(fullPath);
      await fs.ensureDir(fileDir);

      await Deno.writeTextFile(fullPath, fileContent);

      context.response.status = oak.Status.OK;
      context.response.body = 'File uploaded successfully';
    } catch (error) {
      console.error('Upload error:', error);
      context.response.status = oak.Status.InternalServerError;
      context.response.body = 'Failed to upload file';
    }
  });

const app = new oak.Application();

app.use(router.routes());
app.use(router.allowedMethods());

console.log(`Listening on port ${host}:${port}`);

await app.listen({ port, hostname: host });

async function getPackages(): Promise<string[]> {
  const names: string[] = [];

  for await (const entry of fs.walk(ROOT_PACKAGES_DIR_PATH, {
    maxDepth: 1,
    includeFiles: false,
    followSymlinks: true,
  })) {
    if (entry.path !== ROOT_PACKAGES_DIR_PATH) {
      names.push(entry.name);
    }
  }

  return names;
}

async function getPackageFiles(
  package_: string
): Promise<string[] | undefined> {
  const dirPath = path.join(ROOT_PACKAGES_DIR_PATH, package_);

  if (await fs.exists(dirPath, { isDirectory: true, isReadable: true })) {
    const names: string[] = [];

    for await (const entry of fs.walk(dirPath, {
      maxDepth: 1,
      includeDirs: false,
      followSymlinks: true,
      exts: PACKAGE_FILE_EXTS,
    })) {
      names.push(entry.name);
    }

    return names;
  }
}

async function readPackageFileContent(
  package_: string,
  file: string
): Promise<string | undefined> {
  const dirPath = path.join(ROOT_PACKAGES_DIR_PATH, package_);
  const filePath = path.join(dirPath, file);

  if (
    PACKAGE_FILE_EXTS.includes(path.extname(filePath)) &&
    (await fs.exists(dirPath, { isDirectory: true, isReadable: true })) &&
    (await fs.exists(filePath, { isFile: true, isReadable: true }))
  ) {
    return await Deno.readTextFile(filePath);
  }
}
