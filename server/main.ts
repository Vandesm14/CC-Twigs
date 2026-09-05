/**
 * Serves the Lua packages for mngr.
 *
 * @module
 */

import * as fs from '@std/fs';
import * as path from '@std/path';
import * as cli from '@std/cli';
import * as oak from '@oak/oak';
import { encodeBase64 } from '@std/encoding/base64';
import JSZip from 'jszip';

/** The root dir path that contains the packages. */
const ROOT_PACKAGES_DIR_PATH = 'pkgs/';
/** Valid package file extensions. */
const PACKAGE_FILE_EXTS = ['.lua'];
/** A RegExp that matches `require("...")`. */
const REQUIRE_REGEXP = /(?<=require\(("|')).*(?=("|')\))/g;

/** Path to the Minecraft instance dir, for pulling item textures out of mod jars. */
const MC_INSTANCE_DIR = Deno.env.get('MC_INSTANCE_DIR');

/** Dir for the on-disk texture cache, so extracted PNGs survive server restarts. */
const TEXTURE_DISK_CACHE_DIR = 'temp/textures';

/** Cache of namespace -> all jar paths holding that namespace's assets. Stores in-flight promises to dedupe concurrent lookups for the same namespace. */
const namespaceJarsCache = new Map<string, Promise<string[]>>();
/** Cache of loaded jars, keyed by jar path. Stores in-flight promises to dedupe concurrent loads of the same jar. */
const jarCache = new Map<string, Promise<JSZip>>();
/** Cache of extracted texture bytes, keyed by `namespace/item` (undefined = not found). Stores in-flight promises to dedupe concurrent lookups for the same texture. */
const textureCache = new Map<string, Promise<Uint8Array | undefined>>();

const args = cli.parseArgs(Deno.args);
const port = typeof args.port === 'number' ? args.port : 3000;
const host = typeof args.host === 'string' ? args.host : 'localhost';

const router = new oak.Router();

router
  /// Serve the warehouse viewer page.
  .get('/warehouse', async (context) => {
    context.response.type = 'text/html';
    context.response.body = await Deno.readTextFile('public/warehouse.html');
  })
  /// Respond with the first uploads/*/slots.json found, plus its transactions.csv.
  .get('/api/warehouse', async (context) => {
    const dir = await findFirstUploadDir();

    if (typeof dir === 'undefined') {
      context.response.status = oak.Status.NotFound;
      context.response.body = 'No uploads found';
      return;
    }

    const slots = JSON.parse(
      await Deno.readTextFile(path.join(dir, 'slots.json'))
    );

    let transactions: Record<string, string>[] = [];
    const txPath = path.join(dir, 'transactions.csv');

    if (await fs.exists(txPath, { isFile: true, isReadable: true })) {
      transactions = parseCsv(await Deno.readTextFile(txPath));
    }

    context.response.type = 'application/json';
    context.response.body = { ...slots, transactions };
  })
  /// Respond with the PNG texture for an item, pulled from the Minecraft instance's jars.
  .get('/api/texture/:namespace/:item', async (context) => {
    const { namespace, item } = context.params;
    const png = await findTexture(namespace, item);

    if (typeof png === 'undefined') {
      context.response.status = oak.Status.NotFound;
      return;
    }

    context.response.type = 'image/png';
    context.response.headers.set('Cache-Control', 'public, max-age=86400');
    context.response.body = png;
  })
  /// Batch-fetch textures as data URIs, keyed by `namespace:item` name, in one request.
  .post('/api/textures', async (context) => {
    const { names } = await context.request.body.json();

    if (!Array.isArray(names)) {
      context.response.status = oak.Status.BadRequest;
      context.response.body = 'Expected { names: string[] }';
      return;
    }

    const unique = [...new Set(names)] as string[];
    const result: Record<string, string> = {};

    await Promise.all(
      unique.map(async (name) => {
        const [namespace, item] = name.split(':');
        if (!namespace || !item) return;

        const png = await findTexture(namespace, item);
        if (png) {
          result[name] = `data:image/png;base64,${encodeBase64(png)}`;
        }
      })
    );

    context.response.type = 'application/json';
    context.response.body = result;
  })
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

/** Finds the dir of the first `uploads/*\/slots.json` found. */
async function findFirstUploadDir(): Promise<string | undefined> {
  for await (const entry of fs.walk('uploads', {
    maxDepth: 2,
    includeDirs: false,
    match: [/slots\.json$/],
  })) {
    return path.dirname(entry.path);
  }
}

/** Parses a CSV with a header row into an array of row objects. */
function parseCsv(text: string): Record<string, string>[] {
  const lines = text.trim().split('\n');
  const header = lines.shift()?.split(',') ?? [];

  return lines.map((line) => {
    const cells = line.split(',');
    return Object.fromEntries(header.map((h, i) => [h, cells[i] ?? '']));
  });
}

/** Finds and caches the PNG bytes for an item's texture, searching mod jars for its namespace. */
function findTexture(
  namespace: string,
  item: string
): Promise<Uint8Array | undefined> {
  const cacheKey = `${namespace}/${item}`;

  const cached = textureCache.get(cacheKey);
  if (cached) return cached;

  const promise = findTextureUncached(namespace, item);
  textureCache.set(cacheKey, promise);
  return promise;
}

/** Does the actual work of {@link findTexture}, including the on-disk cache. */
async function findTextureUncached(
  namespace: string,
  item: string
): Promise<Uint8Array | undefined> {
  const diskPath = path.join(TEXTURE_DISK_CACHE_DIR, namespace, `${item}.png`);

  if (await fs.exists(diskPath, { isFile: true, isReadable: true })) {
    return await Deno.readFile(diskPath);
  }

  const jarPaths = await findNamespaceJars(namespace);

  for (const jarPath of jarPaths) {
    const zip = await loadJar(jarPath);
    const entry =
      zip.file(`assets/${namespace}/textures/item/${item}.png`) ??
      zip.file(`assets/${namespace}/textures/block/${item}.png`);

    if (entry) {
      const png = await entry.async('uint8array');
      await cacheTextureToDisk(diskPath, png);
      return png;
    }
  }

  // Many blocks/items (e.g. multi-texture blocks) have no texture at the
  // guessed path directly; resolve it through the item/block model chain
  // instead (item model -> parent block model -> its "particle" texture).
  const resolved = await resolveModelTexture(namespace, `item/${item}`);

  if (resolved) {
    const resolvedJars = await findNamespaceJars(resolved.namespace);

    for (const jarPath of resolvedJars) {
      const zip = await loadJar(jarPath);
      const entry = zip.file(
        `assets/${resolved.namespace}/textures/${resolved.path}.png`
      );

      if (entry) {
        const png = await entry.async('uint8array');
        await cacheTextureToDisk(diskPath, png);
        return png;
      }
    }
  }
}

/** Writes an extracted texture to the on-disk cache. */
async function cacheTextureToDisk(
  diskPath: string,
  png: Uint8Array
): Promise<void> {
  await fs.ensureDir(path.dirname(diskPath));
  await Deno.writeFile(diskPath, png);
}

/** Resolves a model's representative texture by walking its `parent` chain. */
async function resolveModelTexture(
  namespace: string,
  modelPath: string,
  depth = 0
): Promise<{ namespace: string; path: string } | undefined> {
  if (depth > 8) return undefined;

  const jarPaths = await findNamespaceJars(namespace);
  let model: { textures?: Record<string, string>; parent?: string } | undefined;

  for (const jarPath of jarPaths) {
    const zip = await loadJar(jarPath);
    const entry = zip.file(`assets/${namespace}/models/${modelPath}.json`);

    if (entry) {
      model = JSON.parse(await entry.async('text'));
      break;
    }
  }

  if (!model) return undefined;

  const ref =
    model.textures?.layer0 ??
    model.textures?.particle ??
    Object.values(model.textures ?? {})[0];

  if (ref) {
    const [ns, path] = ref.includes(':') ? ref.split(':') : [namespace, ref];
    return { namespace: ns, path };
  }

  if (model.parent) {
    const [ns, path] = model.parent.includes(':')
      ? model.parent.split(':')
      : [namespace, model.parent];
    return await resolveModelTexture(ns, path, depth + 1);
  }
}

/** Finds and caches every jar (mod jars, or the vanilla client jar) that holds a namespace's assets. */
function findNamespaceJars(namespace: string): Promise<string[]> {
  const cached = namespaceJarsCache.get(namespace);
  if (cached) return cached;

  const promise =
    namespace === 'minecraft'
      ? findVanillaClientJars()
      : findModJarsForNamespace(namespace);

  namespaceJarsCache.set(namespace, promise);
  return promise;
}

/** Searches `mods/*.jar` in the instance dir for every jar containing `assets/<namespace>/`. */
async function findModJarsForNamespace(namespace: string): Promise<string[]> {
  if (typeof MC_INSTANCE_DIR === 'undefined') return [];

  const modsDir = path.join(MC_INSTANCE_DIR, 'mods');
  if (!(await fs.exists(modsDir, { isDirectory: true }))) return [];

  const matches: string[] = [];

  for await (const entry of fs.walk(modsDir, {
    maxDepth: 1,
    includeDirs: false,
    exts: ['.jar'],
  })) {
    const zip = await loadJar(entry.path);
    if (Object.keys(zip.files).some((f) => f.startsWith(`assets/${namespace}/`))) {
      matches.push(entry.path);
    }
  }

  return matches;
}

/** Finds the vanilla client jar(s) bundled alongside the PrismLauncher instance. */
async function findVanillaClientJars(): Promise<string[]> {
  if (typeof MC_INSTANCE_DIR === 'undefined') return [];

  // MC_INSTANCE_DIR = <PrismLauncher root>/instances/<instance>/minecraft
  const prismRoot = path.resolve(MC_INSTANCE_DIR, '../../..');
  const librariesDir = path.join(
    prismRoot,
    'libraries/com/mojang/minecraft'
  );

  if (!(await fs.exists(librariesDir, { isDirectory: true }))) return [];

  const matches: string[] = [];

  for await (const entry of fs.walk(librariesDir, {
    maxDepth: 2,
    includeDirs: false,
    match: [/-client\.jar$/],
  })) {
    matches.push(entry.path);
  }

  return matches;
}

/** Loads and caches a jar's contents. */
function loadJar(jarPath: string): Promise<JSZip> {
  const cached = jarCache.get(jarPath);
  if (cached) return cached;

  const promise = Deno.readFile(jarPath).then((bytes) => JSZip.loadAsync(bytes));
  jarCache.set(jarPath, promise);
  return promise;
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
