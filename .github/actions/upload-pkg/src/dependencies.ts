import { Config } from "./types";

const projectPefix = "morpheus-graphql";

type Matrix = string[][];

const genGap = (item: number, max: number) =>
  Array.from({ length: max - item }, () => " ").join("");

const getSize = (mx: Matrix, index: number) =>
  Math.max(...mx.map((xs) => xs[index]?.length ?? 0));

const formatMatrix = (xs: Matrix) =>
  xs.map((row) =>
    row
      .reduce(
        (txt, item, i) =>
          txt + item + genGap(item.length, getSize(xs, i)) + "  ",
        ""
      )
      .trim()
  );

const rules: Record<string, [string, string]> = {
  aeson: ["1.4.4.0", "3"],
  base: ["4.7", "5"],
  bytestring: ["0.10.4", "0.11"],
  containers: ["0.4.2.1", "0.7"],
  megaparsec: ["7.0.0", "10.0.0"],
  mtl: ["2.0", "3.0"],
  scientific: ["0.3.6.2", "0.4"],
  text: ["1.2.3.0", "1.3"],
  transformers: ["0.3", "0.6"],
  ["template-haskell"]: ["2.0", "3.0"],
  ["th-lift-instances"]: ["0.1.1", "0.3"],
  ["unordered-containers"]: ["0.2.8.0", "0.3"],
  ["unliftio-core"]: ["0.0.1", "0.4"],
  vector: ["0.12.0.1", "0.13"],
  websockets: ["0.11", "1.0"],
  hashable: ["1.0.0", "2.0"],
  relude: ["0.3.0", "2.0"],
  directory: ["1.0", "2.0"],
  uuid: ["1.0", "1.4"],
  filepath: ["1.1", "1.5"],
  tasty: ["0.1", "1.5"],
  ["tasty-hunit"]: ["0.1", "1.0"],
  ["optparse-applicative"]: ["0.12", "0.18"],
  prettyprinter: ["1.2", "2.0"],
};

const withRule = (name: string, [min, max]: [string, string]) => [
  name,
  ">=",
  min,
  "&&",
  "<",
  max,
];

const updateDependency =
  ({ bounds }: Config) =>
  ([name, ...args]: string[]): string[] => {
    if (name.startsWith(projectPefix)) {
      if (!args.length) {
        return [name, ...args];
      }
      return withRule(name, bounds);
    }
    const rule = rules[name];

    if (rule) {
      return withRule(name, rule);
    }

    console.warn("unknown package:", name);

    return [name, ...args];
  };

export const formatDeps = (config: Config) => (dependencies: string[]) =>
  formatMatrix(
    dependencies
      .map((d) => d.split(/\s+/))
      .sort(([a], [b]) => a.charCodeAt(0) - b.charCodeAt(0))
      .map(updateDependency(config))
  );
