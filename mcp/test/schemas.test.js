import { test } from "node:test";
import assert from "node:assert/strict";
import { frameSchema, itemsSchema, zonesSchema, workspaceItemsSchema } from "../dist/schemas.js";

// Frames are fractions of a monitor's visible area, origin top-left. The
// bounds are the whole reason an agent can say "left 60%" without knowing how
// many pixels wide the screen is.
test("a frame is a fraction of the screen", () => {
  assert.equal(frameSchema.safeParse({ x: 0, y: 0, w: 0.6, h: 1 }).success, true);
});

test("a frame in pixels is refused", () => {
  // The mistake an agent actually makes: passing points instead of fractions.
  assert.equal(frameSchema.safeParse({ x: 0, y: 0, w: 1440, h: 900 }).success, false);
});

test("a frame off the top or left of the screen is refused", () => {
  assert.equal(frameSchema.safeParse({ x: -0.1, y: 0, w: 0.5, h: 1 }).success, false);
});

test("a frame missing a side is refused", () => {
  assert.equal(frameSchema.safeParse({ x: 0, y: 0, w: 0.5 }).success, false);
});

test("a layout places at least one window", () => {
  assert.equal(itemsSchema.safeParse([]).success, false);
});

test("a layout item needs an app and a frame", () => {
  const ok = itemsSchema.safeParse([{ app: "Safari", frame: { x: 0, y: 0, w: 0.5, h: 1 } }]);
  assert.equal(ok.success, true);
  assert.equal(itemsSchema.safeParse([{ frame: { x: 0, y: 0, w: 0.5, h: 1 } }]).success, false);
});

test("a zone set is not empty", () => {
  assert.equal(zonesSchema.safeParse([]).success, false);
  assert.equal(zonesSchema.safeParse([{ x: 0, y: 0, w: 0.5, h: 1 }]).success, true);
});

test("a workspace item carries what it takes to launch the app again", () => {
  const item = {
    app: "Visual Studio Code",
    bundle_id: "com.microsoft.VSCode",
    screen_uuid: "37D8832A-2D66-02CA-B9F7-8F30A301B230",
    frame: { x: 0, y: 0, w: 0.5, h: 1 },
    urls: ["/Users/me/project"],
  };
  assert.equal(workspaceItemsSchema.safeParse([item]).success, true);
});

test("a workspace item with a pixel frame is refused", () => {
  const item = { app: "Safari", frame: { x: 0, y: 0, w: 1440, h: 900 } };
  assert.equal(workspaceItemsSchema.safeParse([item]).success, false);
});
