// Real browser + Jac endpoint checks. Use a disposable localhost graph store.
// Adds its own votes and removes them in finally; no models or response mocking.
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const {chromium} = require('playwright');
const base = process.env.TRACE_MEDIA_URL || 'http://localhost:8098';
if (!['localhost', '127.0.0.1'].includes(new URL(base).hostname)) {
  throw Error('Use an isolated localhost preview: this check writes temporary votes.');
}
const output = process.env.TRACE_MEDIA_RESULTS || '/tmp/trace-media-browser.json';
const screenshotDir = process.env.TRACE_MEDIA_SCREENSHOTS;
const report = {checks: [], errors: [], requests: []};
const check = (name, detail) => { report.checks.push({name, detail}); console.log('PASS', name); };

(async () => {
  const browser = await chromium.launch({headless: true,
    ...(process.env.TRACE_BROWSER_EXECUTABLE ? {executablePath: process.env.TRACE_BROWSER_EXECUTABLE} : {})});
  const context = await browser.newContext({viewport: {width: 1440, height: 1000}});
  const page = await context.newPage();
  const voterKey = randomUUID(), cleanup = [];
  await context.addInitScript(key => {
    if (!localStorage.getItem('trace-media-voter-v1')) localStorage.setItem('trace-media-voter-v1', key);
  }, voterKey);
  page.on('pageerror', e => report.errors.push(e.message));
  page.on('request', r => { if (r.url().includes('/assets/community-media/')) report.requests.push(r.url()); });
  page.on('response', r => {
    if (r.url().includes('/assets/community-media/') && r.status() >= 400) report.errors.push(`${r.status()} ${r.url()}`);
  });
  const library = () => page.getByLabel('Shared media library', {exact: true});
  const cards = () => library().locator('article');
  const ids = async () => cards().evaluateAll(elements => elements.map(el => el.dataset.mediaId));
  const type = () => library().getByRole('combobox', {name: 'Media type', exact: true});
  const sort = () => library().getByRole('combobox', {name: 'Sort media', exact: true});
  async function call(name, data = {}) {
    const response = await context.request.post(`${base}/function/${name}`, {data});
    assert.equal(response.ok(), true);
    const body = await response.json();
    assert.equal(body.ok, true, JSON.stringify(body.error));
    return body.data.result;
  }
  async function enterMedia(target = page) {
    await target.getByRole('tab', {name: 'Media', exact: true}).click();
    await target.getByText('20 photos · 9 videos', {exact: true}).waitFor();
  }
  try {
    const baseline = await call('community_media');
    assert.equal(baseline.length, 29);
    assert.ok(baseline.every(row => row.vote_count === 0), 'Use a disposable store without existing votes.');
    const newest = [...baseline].sort((a, b) => b.order - a.order);
    await page.goto(base);
    await enterMedia();
    await page.waitForTimeout(400);
    assert.deepEqual(await ids(), newest.slice(0, 12).map(row => row.id));
    assert.ok(report.requests.length > 0 && report.requests.every(url => url.endsWith('-thumb.jpg')));
    assert.equal(await library().locator('video').count(), 0);
    check('Initial 12 cards are in true newest-added order and request only thumbnails');

    await library().getByRole('button', {name: 'Show more media', exact: true}).click();
    assert.equal(await cards().count(), 24);
    await library().getByRole('button', {name: 'Show more media', exact: true}).click();
    assert.deepEqual(await ids(), newest.map(row => row.id));
    check('Show more exposes all 29 unique cards in deterministic order');

    await type().selectOption('video');
    assert.equal(await cards().count(), 9);
    for (const poster of await library().locator('img').all()) {
      await poster.scrollIntoViewIfNeeded();
      await poster.evaluate(img => img.decode());
      assert.ok(await poster.evaluate(img => img.naturalWidth > 0 && img.naturalWidth <= 640));
    }
    assert.equal(await library().locator('video').count(), 0);
    assert.equal(report.requests.filter(url => url.endsWith('.mp4')).length, 0);
    check('All nine thumbnails decode, with ZERO video requests before Play');

    await library().getByRole('button', {name: 'Play Clip 01', exact: true}).click();
    const video = library().getByLabel('Clip 01', {exact: true});
    await page.waitForFunction(() => {
      const v = document.querySelector('[aria-label="Shared media library"] video');
      return v && v.readyState >= 2 && v.currentTime > 0;
    });
    assert.equal(new Set(report.requests.filter(url => url.endsWith('.mp4'))).size, 1);
    const playback = await video.evaluate(v => {
      v.pause(); return {duration: v.duration, width: v.videoWidth, height: v.videoHeight, preload: v.preload};
    });
    assert.ok(playback.duration > 0);
    assert.equal(playback.preload, 'none');
    const clip = baseline.find(row => row.title === 'Clip 01');
    const range = await context.request.get(base + clip.url, {headers: {Range: 'bytes=0-1023'}});
    // Jac 0.34.1 static serving currently ignores Range. Keep this limitation
    // visible rather than claiming the selected clip is served in byte chunks.
    const received = (await range.body()).length;
    assert.ok([200, 206].includes(range.status()));
    assert.equal(received, range.status() === 206 ? 1024 : clip.bytes);
    check('Only the chosen clip plays; static-server range behavior measured',
      {...playback, rangeStatus: range.status(), receivedBytes: received});

    await type().selectOption('image');
    const target = cards().last(), voted = await target.getAttribute('data-media-id');
    cleanup.push({asset_id: voted, browser_key: voterKey});
    await target.getByRole('button', {name: /Useful for review/}).click();
    await library().getByText(/Marked Photo .* useful\./).waitFor();
    assert.equal(await cards().first().getAttribute('data-media-id'), voted);
    assert.equal(await cards().first().getByRole('button', {pressed: true}).count(), 1);
    check('A UI vote updates the shared count and moves the file first');

    await page.reload(); await enterMedia();
    assert.equal(await cards().first().getAttribute('data-media-id'), voted);
    assert.equal(await cards().first().getByRole('button', {pressed: true}).count(), 1);
    const second = await browser.newPage();
    await second.goto(base); await enterMedia(second);
    const first = second.getByLabel('Shared media library', {exact: true}).locator('article').first();
    assert.equal(await first.getAttribute('data-media-id'), voted);
    assert.equal(await first.getByRole('button', {pressed: false}).count(), 1);
    assert.equal((await call('community_media')).find(row => row.id === voted).vote_count, 1);
    await second.close();
    check('Reload retains the vote; another browser sees its count without inheriting it');

    await sort().selectOption('newest');
    assert.deepEqual(await ids(), newest.slice(0, 12).map(row => row.id));
    await sort().selectOption('votes');
    await cards().first().getByRole('button', {pressed: true}).click();
    await library().getByText(/Removed your vote/).waitFor();
    assert.deepEqual(await ids(), newest.slice(0, 12).map(row => row.id));
    assert.equal((await call('community_media')).find(row => row.id === voted).vote_count, 0);
    check('Newest ignores vote rank; Undo restores the zero-count newest ordering');

    const high = newest.at(-1).id, low = newest[0].id;
    for (const [asset_id, count] of [[high, 10], [low, 2]]) {
      for (let n = 0; n < count; n++) {
        const browser_key = randomUUID(); cleanup.push({asset_id, browser_key});
        await call('set_media_vote', {asset_id, browser_key, useful: true});
      }
    }
    await library().getByRole('button', {name: 'Refresh media', exact: true}).click();
    await library().getByText('Loading shared media…', {exact: true}).waitFor({state: 'hidden'});
    assert.deepEqual((await ids()).slice(0, 2), [high, low]);
    check('Numeric ranking puts ten actual test votes above two');
    for (const entry of cleanup) await call('set_media_vote', {...entry, useful: false});
    await library().getByRole('button', {name: 'Refresh media', exact: true}).click();
    await library().getByText('Loading shared media…', {exact: true}).waitFor({state: 'hidden'});
    assert.ok((await call('community_media')).every(row => row.vote_count === 0));

    await library().getByRole('searchbox').fill('no-file-matches-this');
    await library().getByText('No supplied media matches this search.', {exact: true}).waitFor();
    assert.equal(await cards().count(), 0);
    await library().getByRole('searchbox').fill('');
    await type().selectOption('video');
    await page.setViewportSize({width: 375, height: 812});
    await cards().first().scrollIntoViewIfNeeded();
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth), 375);
    await cards().first().locator('img').evaluate(img => img.decode());
    if (screenshotDir) await page.screenshot({path: path.join(screenshotDir, 'trace-media-mobile.png')});
    await page.setViewportSize({width: 1440, height: 1000});
    await page.evaluate(() => window.scrollTo(0, 0));
    for (const img of (await library().locator('img').all()).slice(0, 3)) await img.evaluate(el => el.decode());
    if (screenshotDir) await page.screenshot({path: path.join(screenshotDir, 'trace-media-gallery.png')});
    check('Search empty state and 375px layout work with no horizontal overflow');
    assert.deepEqual(report.errors, []);
    report.status = 'PASS';
  } catch (error) {
    report.status = 'FAIL'; report.error = error.stack; process.exitCode = 1;
    console.error(error);
  } finally {
    try {
      for (const entry of cleanup) await call('set_media_vote', {...entry, useful: false});
    } catch (error) {
      report.status = 'FAIL'; report.cleanup_error = error.message; process.exitCode = 1;
    }
    fs.writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
