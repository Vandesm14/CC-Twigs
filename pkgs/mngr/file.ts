export function createFileIfNotExist(path: string, content = '') {
  if (fs.exists(path)) return;
  const [file] = fs.open(path, 'w');

  if (!file) {
    throw new Error(`Could not create file ${path}`);
  }

  file.write(content);
  file.close();
}

export function readOrDefault<T = string>(
  path: string,
  init: T,
  asJSON = false
): T {
  const [file] = fs.open(path, 'r');
  if (!file) {
    return init;
  }
  const data = file.readAll();
  file.close();

  if (data.length === 0) {
    return init;
  }

  if (asJSON) {
    return textutils.unserializeJSON(data) as T;
  }

  return data as T;
}
