import { oak, path } from './deps.ts';

const PORT = 6680;
const PKGS_DIR_PATH = 'pkgs';

const router = new oak.Router();

router.get('/', async (context) => {
  const packages: { libs: Record<string, string[]>; bins: string[] } = {
    libs: {},
    bins: [],
  };

  for await (const walk of Deno.readDir(PKGS_DIR_PATH)) {
    const extension = path.extname(walk.name);
    const name = path.basename(walk.name);

    if (walk.isFile && extension === '.lua') {
      packages.bins.push(name);
    } else if (walk.isDirectory) {
      const lib = name;

      for await (const walk of Deno.readDir(path.join(PKGS_DIR_PATH, lib))) {
        const extension = path.extname(walk.name);
        const name = path.basename(walk.name);

        if (walk.isFile && extension === '.lua') {
          if (typeof (packages.libs[lib]) === 'undefined') {
            packages.libs[lib] = [];
          }

          packages.libs[lib].push(name);
        }
      }
    }
  }

  context.response.body = packages;
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
