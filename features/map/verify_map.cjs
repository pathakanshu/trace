// Run against this worktree's isolated `jac start --dev` preview. See README Map.
const assert = require('node:assert/strict');
const { chromium } = require('playwright');
const base = process.env.TRACE_MAP_URL || 'http://localhost:8092';
if (!['localhost', '127.0.0.1'].includes(new URL(base).hostname)) {
  throw new Error('This check resets demo data. Use an isolated localhost preview.');
}
const results = [];
const browserErrors = [];
const pass = name => { results.push(name); console.log('PASS', name); };
const bridgeButton = page => page.getByLabel('Reported places', { exact: true }).getByRole('button', { name: /^Bhote Koshi Bridge ·/ });
const currentPanel = page => page.getByLabel('Current reports for linked people', { exact: true });
async function openPage(browser, boundaryMode = '') {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  page.on('pageerror', error => browserErrors.push(error.message));
  if (boundaryMode === 'failed') {
    await page.route('**/function/get_boundaries', route => route.abort('failed'));
  }
  if (boundaryMode === 'slow') {
    await page.route('**/function/get_boundaries', async route => {
      const response = await route.fetch();
      await new Promise(resolve => setTimeout(resolve, 7000));
      await route.fulfill({ response });
    });
  }
  await page.goto(base);
  await bridgeButton(page).waitFor();
  return page;
}
async function waitText(locator, text) {
  await locator.filter({ hasText: text }).waitFor();
}
(async () => {
  const browser = await chromium.launch({ headless: true,
    ...(process.env.TRACE_BROWSER_EXECUTABLE ? { executablePath: process.env.TRACE_BROWSER_EXECUTABLE } : {}) });
  try {
    const page = await openPage(browser);
    await page.getByRole('button', { name: 'Demo controls', exact: true }).click();
    await Promise.all([page.waitForResponse(r => r.url().endsWith('/function/get_dashboard')),
      page.getByRole('button', { name: 'Reset demo', exact: true }).click()]);
    await page.getByRole('button', { name: 'Reset demo', exact: true }).waitFor();
    await page.getByRole('button', { name: 'Inspect Bhote Koshi Bridge · Missing', exact: true }).waitFor();
    await bridgeButton(page).focus();
    await page.keyboard.press('Enter');
    await waitText(currentPanel(page), 'Maya Gurung · Reported missing');
    assert.match(await currentPanel(page).innerText(), /Nepal Police Demo/);
    assert.match(await page.getByRole('button', { name: 'Inspect Bhote Koshi Bridge · Missing', exact: true }).locator('span').first().getAttribute('class'), /bg-status-missing/);
    pass('keyboard place selection and cited Missing status');

    await page.getByRole('button', { name: 'Simulate hospital report', exact: true }).click();
    await waitText(currentPanel(page), 'Maya Gurung · Reported safe');
    assert.match(await currentPanel(page).innerText(), /Central Hospital Demo/);
    assert.match(await page.getByLabel('Location evidence', { exact: true }).innerText(), /Nepal Police Demo/);
    assert.match(await page.getByRole('button', { name: 'Inspect Bhote Koshi Bridge · Reported safe', exact: true }).locator('span').first().getAttribute('class'), /bg-status-safe/);
    await page.getByText(/WatchWalker created 1 alert/).waitFor();
    pass('hospital refresh changes pin and citation, preserves police evidence, creates one alert');

    // Move the map using its real controls, then compare marker positions and canvas identity.
    await page.getByRole('button', { name: 'Zoom in', exact: true }).click();
    const canvas = page.locator('canvas.maplibregl-canvas');
    const box = await canvas.boundingBox();
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    await page.mouse.down();
    await page.mouse.move(box.x + box.width / 2 + 30, box.y + box.height / 2 + 20, { steps: 8 });
    await page.mouse.up();
    await page.waitForTimeout(750); // Finish MapLibre zoom/pan animation before comparison.
    const pinPositions = () => page.locator('.maplibregl-marker').evaluateAll(nodes => nodes.map(n => n.style.transform));
    const before = await pinPositions();
    await canvas.evaluate(el => { el.dataset.viewportCheck = 'original'; });
    await page.getByRole('tab', { name: 'People', exact: true }).click();
    await page.getByRole('tab', { name: 'Map', exact: true }).click();
    await page.waitForTimeout(100);
    assert.deepEqual(await pinPositions(), before);
    assert.equal(await canvas.getAttribute('data-viewport-check'), 'original');
    assert.equal(await bridgeButton(page).getAttribute('aria-pressed'), 'true');
    pass('pan/zoom, selected place and canvas survive tab switches');

    await page.setViewportSize({ width: 375, height: 812 });
    await page.waitForTimeout(200);
    const dimensions = await page.evaluate(() => ({ width: innerWidth, document: document.documentElement.scrollWidth,
      canvas: document.querySelector('canvas.maplibregl-canvas').getBoundingClientRect().width }));
    assert.equal(dimensions.document, dimensions.width);
    assert.ok(dimensions.canvas > 250 && dimensions.canvas <= 375);
    await page.getByRole('button', { name: /^Tatopani Market ·/ }).focus();
    await page.keyboard.press('Enter');
    await waitText(currentPanel(page), 'No person is linked');
    await bridgeButton(page).focus();
    await page.keyboard.press('Enter');
    await waitText(currentPanel(page), 'Central Hospital Demo');
    if (process.env.TRACE_MAP_SCREENSHOT) await page.screenshot({ path: process.env.TRACE_MAP_SCREENSHOT, fullPage: true });
    pass('375px has no document overflow; keyboard evidence selection and map sizing work');

    // Execute the real compiled browser helpers for status and citation edge cases.
    const semantics = await page.evaluate(async () => {
      const { pin_status, current_reports, linked_people } = await import('/compiled/features/map/Status.js');
      const safe = { id: 'safe', latest_status: 'FOUND_SAFE', has_conflict: false };
      const missing = { id: 'missing', latest_status: 'MISSING', has_conflict: false };
      const conflict = { id: 'conflict', latest_status: 'UNKNOWN', has_conflict: true };
      const claims = [
        { id: 'old', claim_type: 'MISSING', timestamp: '2026-09-20' },
        { id: 'hospital', claim_type: 'FOUND_SAFE', timestamp: '2026-09-21' },
        { id: 'police', claim_type: 'MISSING', timestamp: '2026-09-21' }
      ];
      return { priorities: [pin_status([]), pin_status([safe]), pin_status([safe, conflict]), pin_status([safe, conflict, missing]),
        pin_status([safe, { latest_status: 'INJURED', has_conflict: false }])],
        conflictCitations: current_reports({ has_conflict: true, claims }).map(c => c.id),
        latestCitation: current_reports({ has_conflict: false, claims: claims.slice(0, 2) }).map(c => c.id),
        linked: linked_people({ evidence: [{ person_id: 'safe' }, { person_id: 'safe' }, { person_id: '' }] }, [safe, missing]).map(p => p.id) };
    });
    assert.deepEqual(semantics, { priorities: ['UNKNOWN', 'FOUND_SAFE', 'REVIEW', 'MISSING', 'REVIEW'],
      conflictCitations: ['hospital', 'police'], latestCitation: ['hospital'], linked: ['safe'] });
    pass('current-status priorities, conflicting citations and distinct person IDs');

    await page.reload();
    await page.getByRole('button', { name: 'Inspect Bhote Koshi Bridge · Reported safe', exact: true }).waitFor();
    pass('updated map status persists after reload');
    await page.getByRole('button', { name: 'Demo controls', exact: true }).click();
    await Promise.all([page.waitForResponse(r => r.url().endsWith('/function/get_dashboard')),
      page.getByRole('button', { name: 'Reset demo', exact: true }).click()]);
    await page.getByRole('button', { name: 'Reset demo', exact: true }).waitFor();
    await page.getByRole('button', { name: 'Inspect Bhote Koshi Bridge · Missing', exact: true }).waitFor();
    await page.getByText('No notifications yet', { exact: true }).waitFor();
    pass('reset restores Missing and removes the demo alert');
    await page.close();

    const failed = await openPage(browser, 'failed');
    await failed.getByText(/Boundaries unavailable/).waitFor();
    await failed.getByRole('button', { name: 'Inspect Bhote Koshi Bridge · Missing', exact: true }).click();
    await waitText(currentPanel(failed), 'Nepal Police Demo');
    pass('failed boundary request preserves pins, place list and evidence');
    await failed.close();

    const slow = await openPage(browser, 'slow');
    await slow.getByRole('button', { name: 'Inspect Bhote Koshi Bridge · Missing', exact: true }).waitFor({ timeout: 4000 });
    await bridgeButton(slow).click();
    await waitText(currentPanel(slow), 'Nepal Police Demo');
    await slow.getByText(/Boundaries unavailable/).waitFor({ timeout: 7000 });
    await slow.getByText(/Boundaries unavailable/).waitFor({ state: 'hidden', timeout: 10000 });
    assert.equal(await bridgeButton(slow).getAttribute('aria-pressed'), 'true');
    pass('slow boundaries time out visibly, then recover without losing evidence selection');
    await slow.close();
    assert.deepEqual(browserErrors, []);
    console.log(JSON.stringify({ checks_passed: results.length, browser_errors: browserErrors, checks: results }, null, 2));
  } catch (error) {
    for (const context of browser.contexts()) for (const page of context.pages()) {
      console.error((await page.locator("body").innerText()).slice(0,7000));
    }
    throw error;
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
