#!/usr/bin/env node
// Validates every set in zone-sets/ against the same rules the app enforces in
// ZoneRect(dict:), so a layout that passes here cannot be refused by /zones/save.
//
// It runs on its own CI job with no macOS runner and no Swift toolchain, which
// is the point: a pull request that adds one JSON file gets an answer in
// seconds instead of waiting on a build it did not touch.
//
// Usage:
//   node scripts/check-zone-sets.mjs             validate
//   node scripts/check-zone-sets.mjs --preview   validate, then draw each set

import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const DIR = join(dirname(fileURLToPath(import.meta.url)), "..", "zone-sets");

// Kept in step with BuiltinZoneSets.all in App/Sources/plonk/Zones.swift. A
// contributed set that shadows one of these would be unreachable: the built-in
// wins in Config.zones(named:).
const BUILTINS = ["Halves", "Thirds", "60 / 40", "Quarters", "Priority"];
const SCREENS = ["any", "wide", "ultrawide", "portrait", "laptop"];
// ZoneGeometry.minSide: the editor cannot draw a zone smaller than this, so a
// set with one could not be adjusted after it was installed.
const MIN_SIDE = 0.1;
// ZoneRect.nameLimit, read from the schema beside the sets so the two cannot
// drift from each other.
const NAME_LIMIT = JSON.parse(readFileSync(join(DIR, "schema.json"), "utf8"))
  .properties.zones.items.properties.name.maxLength;

const errors = [];
const warnings = [];
const sets = [];

/** The filename a set must use, derived from its name so the two cannot drift. */
const slug = (name) => name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

const files = readdirSync(DIR).filter((f) => f.endsWith(".json") && f !== "schema.json").sort();
if (files.length === 0) errors.push("zone-sets/ has no sets in it");

for (const file of files) {
  const fail = (message) => errors.push(`${file}: ${message}`);
  const raw = readFileSync(join(DIR, file), "utf8");

  if (/[^\x00-\x7F]/.test(raw)) fail("non-ASCII character; the repo has no emoji and no smart quotes anywhere");
  if (!raw.endsWith("\n")) fail("no newline at end of file");

  let set;
  try {
    set = JSON.parse(raw);
  } catch (e) {
    fail(`not valid JSON (${e.message})`);
    continue;
  }

  const allowed = ["name", "description", "screen", "author", "zones"];
  for (const key of allowed) if (!(key in set)) fail(`missing "${key}"`);
  for (const key of Object.keys(set)) {
    if (!allowed.includes(key)) fail(`unknown key "${key}"; schema.json lists what a set may carry`);
  }

  if (typeof set.name === "string") {
    if (set.name.trim() !== set.name || set.name.length === 0 || set.name.length > 40) {
      fail("name must be 1 to 40 characters with no padding");
    }
    if (BUILTINS.includes(set.name)) fail(`"${set.name}" is a built-in set name and would be shadowed by it`);
    if (slug(set.name) !== file.replace(/\.json$/, "")) {
      fail(`name "${set.name}" wants the filename ${slug(set.name)}.json`);
    }
    const clash = sets.find((s) => s.name === set.name);
    if (clash) fail(`name "${set.name}" is already used by ${clash.file}`);
  }

  if (typeof set.description !== "string" || set.description.length === 0 || set.description.length > 200) {
    fail("description must be one line of 1 to 200 characters");
  }
  if (!SCREENS.includes(set.screen)) fail(`screen must be one of ${SCREENS.join(", ")}`);
  if (typeof set.author !== "string" || !/^@[A-Za-z0-9][A-Za-z0-9-]{0,38}$/.test(set.author)) {
    fail("author must be a GitHub handle with the at sign, e.g. @ostapondo");
  }

  if (!Array.isArray(set.zones) || set.zones.length < 1 || set.zones.length > 24) {
    fail("zones must be an array of 1 to 24 rectangles");
    continue;
  }

  const names = new Set();
  set.zones.forEach((zone, i) => {
    const n = i + 1;
    const { name, ...rect } = zone ?? {};
    const keys = Object.keys(rect).sort().join(",");
    if (keys !== "h,w,x,y") {
      fail(`zone ${n} must have exactly x, y, w and h, plus an optional name`);
      return;
    }
    // A name is what voice and an agent call the zone by: ZoneRect.cleanName
    // trims it, cuts it at the limit and refuses a number, and the routes
    // refuse two zones with one name, so a set that passes here installs
    // with the names it shows. A number is what Swift's Int reads, sign
    // included, and padding is any space Swift would trim, zero-width ones
    // included.
    if (name !== undefined) {
      const padded = /^[\s\u200B\uFEFF]|[\s\u200B\uFEFF]$/.test(name);
      if (typeof name !== "string" || padded || name.length === 0 || name.length > NAME_LIMIT) {
        fail(`zone ${n}: name must be 1 to ${NAME_LIMIT} characters with no padding`);
      } else if (/^[+-]?\d+$/.test(name)) {
        fail(`zone ${n}: "${name}" is a number, and numbers already mean the zone in that place`);
      } else if (names.has(name.toLowerCase())) {
        fail(`zone ${n}: the name "${name}" is already used in this set`);
      } else {
        names.add(name.toLowerCase());
      }
    }
    for (const [key, value] of Object.entries(rect)) {
      if (typeof value !== "number" || !Number.isFinite(value)) {
        fail(`zone ${n}: ${key} is not a number`);
        return;
      }
      // Four decimals is past anything the editor can produce, so more of them
      // means a fraction was pasted in from a division rather than drawn.
      if (Math.abs(value * 10000 - Math.round(value * 10000)) > 1e-9) {
        fail(`zone ${n}: ${key} has more than four decimals; round it`);
      }
    }
    const { x, y, w, h } = zone;
    if (x < 0 || y < 0) fail(`zone ${n} starts off the screen`);
    if (w < MIN_SIDE || h < MIN_SIDE) fail(`zone ${n} is under ${MIN_SIDE} on a side; the editor could not redraw it`);
    if (x + w > 1.0001 || y + h > 1.0001) fail(`zone ${n} runs past the edge of the screen`);
  });

  sets.push({ file, ...set });

  // Overlaps are legal and sometimes deliberate, but they make a drag
  // ambiguous, so they are worth saying out loud rather than failing on.
  for (let i = 0; i < set.zones.length; i++) {
    for (let j = i + 1; j < set.zones.length; j++) {
      const a = set.zones[i], b = set.zones[j];
      const over = Math.max(0, Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x))
        * Math.max(0, Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y));
      if (over > 0.0001) warnings.push(`${file}: zones ${i + 1} and ${j + 1} overlap`);
    }
  }
}

/** A set drawn on a character grid, so a review can see the layout in the diff. */
function draw(set, cols = 48, rows = 14) {
  const grid = Array.from({ length: rows }, () => Array(cols).fill(" "));
  set.zones.forEach((z, i) => {
    const x0 = Math.round(z.x * cols), y0 = Math.round(z.y * rows);
    const x1 = Math.max(x0 + 1, Math.round((z.x + z.w) * cols)) - 1;
    const y1 = Math.max(y0 + 1, Math.round((z.y + z.h) * rows)) - 1;
    for (let y = y0; y <= y1; y++) {
      for (let x = x0; x <= x1; x++) {
        const edge = y === y0 || y === y1 || x === x0 || x === x1;
        grid[y][x] = edge ? (y === y0 || y === y1 ? "-" : "|") : " ";
      }
    }
    for (const [y, x] of [[y0, x0], [y0, x1], [y1, x0], [y1, x1]]) grid[y][x] = "+";
    // The number, with the name beside it where the cell has room, centred.
    const full = z.name ? `${i + 1} ${z.name}` : String(i + 1);
    const cy = Math.floor((y0 + y1) / 2), cx = Math.floor((x0 + x1) / 2);
    const label = full.length + 2 <= x1 - x0 ? full : String(i + 1);
    const start = Math.max(x0 + 1, cx - Math.floor(label.length / 2));
    for (let k = 0; k < label.length; k++) grid[cy][start + k] = label[k];
  });
  return grid.map((row) => row.join("").replace(/\s+$/, "")).join("\n");
}

if (process.argv.includes("--preview")) {
  for (const set of sets) {
    console.log(`\n${set.name}  (${set.screen}, ${set.zones.length} zones)  ${set.file}`);
    console.log(draw(set));
  }
  console.log("");
}

for (const warning of warnings) console.log(`warning  ${warning}`);
for (const error of errors) console.error(`error    ${error}`);

if (errors.length > 0) {
  console.error(`\n${errors.length} problem(s) in zone-sets/. The rules are in zone-sets/README.md.`);
  process.exit(1);
}
console.log(`${sets.length} zone set(s) valid.`);
