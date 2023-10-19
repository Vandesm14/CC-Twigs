import { oak, path } from './deps.ts';

const PORT = 6680;
const PKGS_DIR_PATH = 'pkgs';

const router = new oak.Router();

// TODO: The proper implementation could look more like below, and provide
//       endpoints to query the binaries and libraries better.

// router.get('/:lib{.:file}', (context) => {
//   console.log('LIB:', context.params);
//   context.response.status = oak.Status.NotImplemented;
// });

// router.get('/:bin', (context) => {
//   console.log('BIN:', context.params);
//   context.response.status = oak.Status.NotImplemented;
// });

router.get('/', async (context) => {
  const files: PkgFile[] = [];

  for await (const binFile of Deno.readDir(PKGS_DIR_PATH)) {
    if (binFile.isFile) {
      files.push({ type: 'bin', name: binFile.name });
    } else if (binFile.isDirectory) {
      for await (
        const libFile of Deno.readDir(path.join(PKGS_DIR_PATH, binFile.name))
      ) {
        if (libFile.isFile) {
          files.push({
            type: 'lib',
            name: path.join(binFile.name, libFile.name),
          });
        }
      }
    }
  }

  context.response.body = files;
});

router.get('/(.+)', async (context) => {
  try {
    await context.send({ root: PKGS_DIR_PATH });
  } catch {
    context.response.status = oak.Status.NotFound;
  }
});

const app = new oak.Application();

app.use(router.routes());
app.use(router.allowedMethods());

await app.listen({ port: PORT });

type PkgFile = BinFile | LibFile;
type BinFile = { type: 'bin'; name: string };
type LibFile = { type: 'lib'; name: string };
