import { readFileSync } from "node:fs";

interface PackageManifest {
  version: string;
}

export const PACKAGE_VERSION = (JSON.parse(
  readFileSync(new URL("../package.json", import.meta.url), "utf8"),
) as PackageManifest).version;
