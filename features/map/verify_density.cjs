// Browser component fixtures only. No corpus import or runtime trace is claimed.
// Run against the isolated localhost dev preview; see README Map.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');
const base = process.env.TRACE_MAP_URL || 'http://localhost:8092';
if (!['localhost', '127.0.0.1'].includes(new URL(base).hostname)) throw new Error('Use an isolated localhost preview.');
const anchors = JSON.parse(fs.readFileSync(path.join(__dirname, 'bhotekoshi-corridor.geojson'), 'utf8')).features;
const settlements = anchors.filter(f => f.geometry.type === 'Point');
const rows = Array.from({length:170}, (_, i) => ({
  location_id:`fixture-location-${i}`, name:`Fictional browser fixture place ${i}`,
  longitude:settlements[i%4].geometry.coordinates[0], latitude:settlements[i%4].geometry.coordinates[1],
  report_count:i<4?7:8, missing:i<4?4:5, safe:2, other:1
}));
const checks=[];const errors=[];
const pass = name => { checks.push(name); console.log('PASS',name); };
(async () => {
  const browser = await chromium.launch({headless:true,
    ...(process.env.TRACE_BROWSER_EXECUTABLE ? {executablePath:process.env.TRACE_BROWSER_EXECUTABLE} : {})});
  const page=await browser.newPage({viewport:{width:1280,height:900}});
  page.on('pageerror',e=>errors.push(e.message));
  let mode='four';
  await page.route('**/function/get_dashboard',async route=>{
    const response=await route.fetch();const body=await response.json();const snap=body.data.result;
    let places=rows;
    if(mode==='many') places=Array.from({length:25},(_,i)=>({...rows[0],location_id:`fixture-${i}`,name:`Test place ${i+1}`,longitude:85.90+i*0.001,latitude:27.90,report_count:i+1,missing:0,safe:0,other:i+1}));
    if(mode==='empty') places=[];
    snap.place_counts=places;
    snap.located_reports=places.reduce((sum,row)=>sum+row.report_count,0);
    snap.unlocated_reports=mode==='empty'?0:17; // Explicit component fixture, not a corpus measurement.
    if(mode!=='empty') snap.locations=places.map(row=>({...snap.locations[0],id:row.location_id,name:row.name,latitude:row.latitude,longitude:row.longitude,media_ids:[],evidence:[]}));
    await route.fulfill({response,json:body});
  });
  try {
    await page.goto(base);
    await page.getByRole('button',{name:'Kodari · 343 reports',exact:true}).waitFor();
    const semantics=await page.evaluate(async ({rows,anchors})=>{
      const {aggregate_places,density_geojson}=await import('/compiled/features/map/Density.js');
      const before=JSON.stringify(rows);const groups=aggregate_places(rows,anchors);
      const invalid=[{...rows[0],longitude:NaN},{...rows[0],latitude:Infinity},
        {...rows[0],longitude:181},{...rows[0],latitude:91},{...rows[0],longitude:0,latitude:0},
        {...rows[0],longitude:'85.95'},{...rows[0],report_count:-1},{...rows[0],report_count:0},
        {...rows[0],report_count:1.5}];
      return {groups,geo:density_geojson(groups),unchanged:before===JSON.stringify(rows),
        invalid:aggregate_places(invalid),empty:aggregate_places([]),
        axes:aggregate_places([{...rows[0],longitude:0},{...rows[0],latitude:0}]).length};
    },{rows,anchors});
    assert.equal(semantics.unchanged,true);assert.equal(semantics.groups.length,4);
    assert.equal(semantics.groups.reduce((sum,g)=>sum+g.report_count,0),1356);
    assert.deepEqual(semantics.groups.map(g=>g.report_count),[343,343,335,335]);
    assert.deepEqual(semantics.geo.features.map(f=>f.geometry.coordinates).sort(),settlements.map(f=>f.geometry.coordinates).sort());
    assert.deepEqual(semantics.invalid,[]);assert.deepEqual(semantics.empty,[]);assert.equal(semantics.axes,2);
    pass('compiled Jac aggregation preserves exact coordinates, counts, input bytes and rejects invalid points');
    assert.match(await page.getByLabel('Report density',{exact:true}).innerText(),/1356 reports with a location, clustered at 4 settlements; 17 reports have no verified location/);
    assert.equal(await page.getByLabel('Busiest report settlements',{exact:true}).getByRole('button').count(),4);
    assert.equal(await page.getByRole('button',{name:/^Inspect /}).count(),0);
    pass('170 location records render four aggregate places without 170 duplicate pins');

    // Click a visible count circle using its settlement marker's rendered anchor.
    const anchor=await page.locator('[data-corridor-settlement="Kodari"]').boundingBox();
    assert.ok(anchor);
    await page.mouse.move(anchor.x-8,anchor.y+anchor.height+8);
    await page.mouse.wheel(0,-1000);
    await page.waitForTimeout(750);
    await page.mouse.wheel(0,-1000);
    await page.waitForTimeout(750);
    const point=await page.evaluate(()=>{
      const canvas=document.querySelector('canvas.maplibregl-canvas').getBoundingClientRect();
      for(const node of document.querySelectorAll('[data-corridor-settlement]')){
        const r=node.getBoundingClientRect();const x=r.left-8;const y=r.bottom+8;
        if(x>canvas.left+25 && x<canvas.right-25 && y>canvas.top+25 && y<canvas.bottom-25) return {x,y,name:node.textContent};
      }
      return null;
    });
    assert.ok(point,'A settlement circle must be visible after zoom');
    await page.mouse.click(point.x,point.y);
    await page.getByLabel('Settlement report counts',{exact:true}).waitFor();
    assert.match(await page.getByLabel('Settlement report counts',{exact:true}).innerText(),new RegExp(point.name));
    pass('high-zoom count circle opens its settlement breakdown');

    await page.getByRole('button',{name:'Kodari · 343 reports',exact:true}).focus();
    await page.keyboard.press('Enter');
    assert.match(await page.getByLabel('Settlement report counts',{exact:true}).innerText(),/343 reports · 214 missing · 86 safe · 43 other/);
    pass('keyboard settlement selection exposes summed missing/safe/other source assertions');
    await page.setViewportSize({width:375,height:812});
    await page.waitForTimeout(250);
    const size=await page.evaluate(()=>({viewport:innerWidth,width:document.documentElement.scrollWidth,caption:document.querySelector('[aria-label="River corridor context"]').getBoundingClientRect().width}));
    assert.equal(size.width,375);assert.ok(size.caption<=375);
    pass('375px density caption, legends and place list have no document overflow');

    mode='many';await page.reload();
    await page.getByRole('button',{name:'Test place 25 · 25 reports',exact:true}).waitFor();
    const buttons=page.getByLabel('Busiest report settlements',{exact:true}).getByRole('button');
    assert.equal(await buttons.count(),20);
    assert.equal(await buttons.first().innerText(),'Test place 25 · 25 reports');
    assert.equal(await buttons.last().innerText(),'Test place 6 · 6 reports');
    pass('place list is capped to 20 and ordered by report count');

    mode='empty';await page.reload();
    await page.getByRole('button',{name:/^Bhote Koshi Bridge ·/}).waitFor();
    assert.equal(await page.getByLabel('Report density',{exact:true}).count(),0);
    assert.equal(await page.getByRole('button',{name:/^Inspect /}).count(),2);
    await page.getByRole('button',{name:/^Bhote Koshi Bridge ·/}).click();
    await page.getByLabel('Location evidence',{exact:true}).waitFor();
    pass('empty counts preserve demo pins, place selection and evidence');

    await page.route('**/function/get_bhotekoshi_corridor',route=>route.abort('failed'));
    await page.reload();await page.getByText(/River corridor unavailable/).waitFor();
    await page.getByRole('button',{name:/^Bhote Koshi Bridge ·/}).click();
    assert.match(await page.getByLabel('Location evidence',{exact:true}).innerText(),/Nepal Police Demo/);
    pass('failed corridor request preserves graph-backed evidence');
    assert.deepEqual(errors,[]);
    console.log(JSON.stringify({component_fixture_checks:checks.length,browser_errors:errors,checks},null,2));
  } catch(error) {
    await page.screenshot({path:'/private/tmp/trace-density-fixture-debug.png',fullPage:true});
    console.error('Page errors:',errors);console.error((await page.locator('body').innerText()).slice(0,5000));throw error;
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
