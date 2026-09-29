// Compare case animation CPU use on a phone-sized software-drawn page.
// PORT=8080 PAGE=dev/test/out/review-candidate.html node caseperf.js label
// Run the same command against a baseline page and compare distributions.
const { chromium } = require('playwright');
const label = process.argv[2] || 'build';
const pageName = process.env.PAGE || 'debug.html';
const url = `http://localhost:${process.env.PORT || 8080}/${pageName}?debug=1`;

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM || undefined,
    args: ['--disable-gpu', '--disable-accelerated-2d-canvas'],
  });
  const page = await browser.newPage({
    viewport: { width: 390, height: 844 }, deviceScaleFactor: 3,
    hasTouch: true, isMobile: true,
  });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(url);
  await page.waitForFunction(() => window.__pal);
  await page.evaluate(() => {
    __pal.locker.cases = 4;
    __pal.showPage('locker');
    __pal.renderLocker();
    window.__reviewReelReads = 0;
    const original = window.getComputedStyle;
    window.getComputedStyle = function (element, ...rest) {
      if (element && element.id === 'reel') window.__reviewReelReads++;
      return original.call(this, element, ...rest);
    };
  });
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Performance.enable');
  const metric = async name => (await cdp.send('Performance.getMetrics')).metrics.find(m => m.name === name).value;
  const measure = async (duration, trigger) => {
    const task0 = await metric('TaskDuration');
    const layout0 = await metric('LayoutCount');
    const style0 = await metric('RecalcStyleCount');
    await trigger();
    await page.waitForTimeout(duration);
    return {
      cpu_ms_per_s: +((await metric('TaskDuration') - task0) * 1000 / (duration / 1000)).toFixed(0),
      layouts: (await metric('LayoutCount')) - layout0,
      style_recalcs: (await metric('RecalcStyleCount')) - style0,
    };
  };
  await page.waitForTimeout(800);
  const intro = await measure(2600, () => page.click('[data-open=supply]'));
  await page.waitForFunction(() => !__pal.caseIntroOn);
  await page.waitForFunction(() => document.querySelectorAll('#reel .item').length > 0);
  const reel = await measure(3400, async () => {});
  reel.computed_style_reads = await page.evaluate(() => window.__reviewReelReads);
  await page.waitForFunction(() => !document.getElementById('caseResult').hidden);
  reel.selected_item_matches_result = await page.evaluate(() =>
    document.querySelectorAll('#reel .item')[29]?.querySelector('b')?.textContent ===
    document.getElementById('caseName').textContent
  );
  const result = { label, intro, reel, errors };
  console.log(JSON.stringify(result));
  await browser.close();
  if (errors.length || !reel.selected_item_matches_result) process.exitCode = 1;
})().catch(error => { console.error(error); process.exitCode = 1 });
