// Renders scene.html frame by frame. Animations are paused and their
// currentTime is set explicitly, so the frames are deterministic and the
// last one lands exactly one period after the first.
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const W = 640, H = 340, PERIOD = 3000, FRAMES = 36, SCALE = 2;
const outDir = path.join(__dirname, 'frames');

(async () => {
  fs.rmSync(outDir, { recursive: true, force: true });
  fs.mkdirSync(outDir, { recursive: true });

  // The installed playwright pins a newer build than the image ships, so
  // point it at the Chromium that is actually here.
  const browser = await chromium.launch({
    executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  });
  const ctx = await browser.newContext({
    viewport: { width: W, height: H },
    deviceScaleFactor: SCALE,
  });
  const page = await ctx.newPage();
  await page.goto('file://' + path.join(__dirname, 'scene.html'));
  await page.waitForTimeout(300);

  const n = await page.evaluate(() => {
    const all = document.getAnimations();
    all.forEach(a => a.pause());
    return all.length;
  });
  console.log('paused animations:', n);

  for (let i = 0; i < FRAMES; i++) {
    const t = (i * PERIOD) / FRAMES;
    await page.evaluate(time => {
      document.getAnimations().forEach(a => { a.currentTime = time; });
    }, t);
    // No animations:'disabled' here — it would rewind the very animations
    // whose currentTime we just set.
    await page.screenshot({
      path: path.join(outDir, `f${String(i).padStart(3, '0')}.png`),
    });
  }

  await browser.close();
  console.log('wrote', FRAMES, 'frames to', outDir);
})();
