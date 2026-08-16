// Renders scene.html frame by frame. Animations are paused and their
// currentTime is set explicitly, so the frames are deterministic and the
// last one lands exactly one period after the first.
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

// 50 frames over 3000 ms is 60 ms each. GIF stores frame delays in
// centiseconds, so only multiples of 10 ms survive the container — 36
// frames wanted 83 ms and got 80, making the loop 2.88 s, not 3.
const W = 640, H = 340, PERIOD = 3000, FRAMES = 50, SCALE = 2;
const outDir = path.join(__dirname, 'frames');

(async () => {
  fs.rmSync(outDir, { recursive: true, force: true });
  fs.mkdirSync(outDir, { recursive: true });

  // The image this was drafted on ships a Chromium that the installed
  // playwright does not pin, so it has to be pointed at the one that is
  // actually there. That path does not exist on a Mac, where playwright
  // downloads its own — hence the fallback rather than a hard path.
  const pinned = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
  const browser = await chromium.launch(
    fs.existsSync(pinned) ? { executablePath: pinned } : {});
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
