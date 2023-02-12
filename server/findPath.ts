// function findPath(
//   graph: Record<number, Array<number>>,
//   start: number,
//   end: number
// ): number[] | null {
//   const queue = [[start]];
//   const visited = new Set<number>();

//   while (queue.length) {
//     const path = queue.shift()!;
//     const node = path[path.length - 1];

//     if (node === end) {
//       return path;
//     }

//     for (const neighbor of graph[node] || []) {
//       if (visited.has(neighbor)) {
//         continue;
//       }
//       visited.add(neighbor);
//       queue.push([...path, neighbor]);
//     }
//   }

//   return null;
// }

function findPath(
  graph: Record<number, number[]>,
  start: number,
  end: number
): number[] | null {
  const queue = [[start]];
  const visited = new Set<number>();
  let shortestPath: number[] | null = null;

  while (queue.length) {
    const path = queue.shift()!;
    const node = path[path.length - 1];

    if (node === end) {
      if (!shortestPath || path.length < shortestPath.length) {
        shortestPath = path;
      }
    } else {
      for (const neighbor of graph[node] || []) {
        if (!visited.has(neighbor)) {
          visited.add(neighbor);
          queue.push([...path, neighbor]);
        }
      }
    }
  }

  return shortestPath;
}

const db = {
  1: [9, 2],
  2: [1, 4, 3, 5],
  3: [2, 7, 6],
  4: [2, 8],
  5: [2, 10],
  6: [3, 7],
  7: [3, 6, 12],
  8: [4],
  9: [1],
  10: [5],
  12: [7],
};

console.log(findPath(db, 1, 12));
