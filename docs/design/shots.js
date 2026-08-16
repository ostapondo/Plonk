const { chromium } = require('playwright');
const path = require('path'), fs = require('fs');
const out = path.join(__dirname, 'shots');
const IDS = ['s-zones', 's-desks', 's-drag', 's-menu'];

(async () => {
  fs.rmSync(out, { recursive: true, force: true });
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const ctx = await browser.newContext({ viewport: { width: 1700, height: 1100 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  await page.goto('file://' + path.join(__dirname, 'mac.html'));
  await page.waitForTimeout(400);
  for (const id of IDS) {
    await page.locator('#' + id).screenshot({ path: path.join(out, id + '.png') });
    console.log('shot', id);
  }
  await browser.close();
})();
