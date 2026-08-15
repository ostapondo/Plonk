#!/usr/bin/env node
// Keeps the string catalog and the Swift that reads it in step.
//
// The app holds keys, not sentences: every user-facing string is declared once
// as `Self.key("some.key")` and spelled out once in Localizable.strings. That
// only works if the two sides cannot drift, which is what this checks:
//
//   - every key the code asks for has a value
//   - every value has something asking for it
//   - a key that takes a value takes the same number on both sides
//   - a translation carries the same keys as English, no more and no less
//   - no view smuggles a sentence back into the source
//
// Run from anywhere; it finds the repository itself. No dependencies, and
// plutil is what reads the plural dictionary because it ships with macOS.

import { readdirSync, readFileSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const sources = join(root, "App/Sources/plonk");
const resources = join(sources, "Resources");
const problems = [];

const fail = (message) => problems.push(message);

/// The symbolic half of a key: everything before the first space. Keys that
/// take a value carry their format specifiers after it ("zones.count %lld").
const symbol = (key) => key.split(" ")[0];
const placeholders = (key) => (key.match(/%(?!%)/g) ?? []).length;

// --- The catalog ------------------------------------------------------------

function readStrings(path) {
    const text = readFileSync(path, "utf8");
    const entry = /^"((?:[^"\\]|\\.)*)" = "((?:[^"\\]|\\.)*)";$/gm;
    const found = new Map();
    for (const match of text.matchAll(entry)) {
        if (found.has(match[1])) fail(`${path}: "${match[1]}" is defined twice.`);
        found.set(match[1], match[2]);
    }
    // Anything that looks like an entry but did not parse is a typo, and would
    // otherwise show up as a missing key with no explanation.
    const lines = text.split("\n").filter((line) => line.trim().startsWith('"'));
    if (lines.length !== found.size) {
        fail(`${path}: ${lines.length - found.size} line(s) look like entries but do not parse.`);
    }
    return found;
}

function readPlurals(path) {
    if (!existsSync(path)) return new Map();
    const json = execFileSync("plutil", ["-convert", "json", "-o", "-", path]);
    return new Map(Object.keys(JSON.parse(json)).map((key) => [key, ""]));
}

function catalog(language) {
    const folder = join(resources, `${language}.lproj`);
    return new Map([
        ...readStrings(join(folder, "Localizable.strings")),
        ...readPlurals(join(folder, "Localizable.stringsdict")),
    ]);
}

// --- What the code asks for -------------------------------------------------

function declared() {
    const keys = new Map();
    for (const file of readdirSync(sources).filter((name) => name.endsWith(".swift"))) {
        const text = readFileSync(join(sources, file), "utf8");
        for (const match of text.matchAll(/Self\.key\("((?:[^"\\]|\\.)*)"\)/g)) {
            const key = match[1];
            const name = symbol(key);
            if (keys.has(name)) fail(`${file}: ${name} is declared twice.`);
            // An interpolation in the declaration is a value the catalog has to
            // have a specifier for.
            keys.set(name, { key, file, values: (key.match(/\\\(/g) ?? []).length });
        }
    }
    return keys;
}

// --- Checks -----------------------------------------------------------------

const english = catalog("en");
const asked = declared();

const byName = new Map();
for (const key of english.keys()) {
    const name = symbol(key);
    if (byName.has(name)) fail(`en: ${name} appears twice, as "${byName.get(name)}" and "${key}".`);
    byName.set(name, key);
}

for (const [name, use] of asked) {
    const key = byName.get(name);
    if (key === undefined) {
        fail(`${use.file}: ${name} has no value in en.lproj.`);
        continue;
    }
    if (placeholders(key) !== use.values) {
        fail(`${name}: the code passes ${use.values} value(s), "${key}" takes ${placeholders(key)}.`);
    }
}

for (const name of byName.keys()) {
    if (!asked.has(name)) fail(`en: ${name} is not used by anything. Delete it, or use it.`);
}

// Every other language carries the same keys. A missing one draws English,
// which is survivable; a stale one is a translation of something gone.
for (const folder of readdirSync(resources).filter((name) => name.endsWith(".lproj"))) {
    const language = folder.replace(".lproj", "");
    if (language === "en") continue;
    const other = catalog(language);
    for (const key of english.keys()) {
        if (!other.has(key)) fail(`${language}: "${key}" is missing.`);
    }
    for (const key of other.keys()) {
        if (!english.has(key)) fail(`${language}: "${key}" is not in en.lproj.`);
    }
}

// The permission dialogs macOS draws come from Info.plist, which cannot be
// translated; an InfoPlist.strings beside the catalog is what overrides them.
// Every key in it has to be one the plist actually sets, or it overrides
// nothing and the English stays.
const plist = readFileSync(join(root, "scripts/build.sh"), "utf8");
for (const folder of readdirSync(resources).filter((name) => name.endsWith(".lproj"))) {
    const path = join(resources, folder, "InfoPlist.strings");
    if (!existsSync(path)) {
        fail(`${folder}: no InfoPlist.strings, so the permission dialogs stay English.`);
        continue;
    }
    for (const key of readStrings(path).keys()) {
        if (!plist.includes(`<key>${key}</key>`)) {
            fail(`${folder}: InfoPlist.strings sets ${key}, which build.sh does not write.`);
        }
    }
}

// A literal sentence in a view is the thing this whole arrangement exists to
// stop. Key glyphs and interpolated numbers are not sentences.
const literal = /(?:Text|Button|Label|Menu|Section|Picker|TextField)\("[A-Za-z][^"]{2,}"/;
for (const file of readdirSync(sources).filter((name) => name.endsWith(".swift"))) {
    if (file.startsWith("Strings+")) continue;
    readFileSync(join(sources, file), "utf8").split("\n").forEach((line, index) => {
        if (literal.test(line)) {
            fail(`${file}:${index + 1}: a literal string in a view. Put it in the catalog.`);
        }
    });
}

if (problems.length > 0) {
    for (const problem of problems) console.error(problem);
    console.error(`\nstrings: ${problems.length} problem(s).`);
    process.exit(1);
}
console.log(`strings: clean, ${english.size} keys.`);
