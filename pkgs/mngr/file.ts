export function createFileIfNotExist(path: string, content = '') {
  if (fs.exists(path)) return;
  const [file] = fs.open(path, 'w');

  if (!file) {
    throw new Error(`Could not create file ${path}`);
  }

  file.write(content);
  file.close();
}

export function readOrDefault(path: string, init: string): string {
  const [file] = fs.open(path, 'r');
  if (!file) {
    createFileIfNotExist(path, init);

    return init;
  }

  const data = file.readAll();
  file.close();

  if (data.length === 0) {
    return init;
  }

  return data;
}
