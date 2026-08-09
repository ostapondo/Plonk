import { test } from "node:test";
import assert from "node:assert/strict";
import { captureMode } from "../dist/tools/screenshot.js";

// 'mode' has a default, so a model that names a window and says nothing else
// looks identical to one asking for the whole screen. Guessing wrong in that
// direction is the expensive one: a desktop screenshot answers the question
// plausibly enough that nobody notices it answered a different one.
test("naming a window turns the default into an app capture", () => {
  assert.equal(captureMode("screen", "Spotify", undefined), "app");
  assert.equal(captureMode("screen", undefined, "Weird Fishes"), "app");
});

test("naming nothing leaves the screen alone", () => {
  assert.equal(captureMode("screen", undefined, undefined), "screen");
  assert.equal(captureMode("app", "Spotify", undefined), "app");
});

// Asking for a crosshair is asking for a crosshair. Overriding it would mean a
// user who was promised a picker never sees one.
test("an interactive mode is never overridden", () => {
  assert.equal(captureMode("region", "Spotify", undefined), "region");
  assert.equal(captureMode("window", "Spotify", "Premium"), "window");
});
