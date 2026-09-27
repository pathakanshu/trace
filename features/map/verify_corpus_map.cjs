// Real local corpus -> dashboard -> map integration. No model calls or mocked data.
// Uses the real shared incident selector and unmodified server responses.
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const base = process.env.TRACE_MAP_URL || 'http://localhost:8092';
if (!['localhost', '127.0.0.1'].includes(new URL(base).hostname)) throw Error('Use an isolated localhost preview; this imports corpus data.');
const checks=[];const errors=[];
const pass=name=>{checks.push(name);console.log('PASS',name)};
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.TRACE_BROWSER_EXECUTABLE?{executablePath:process.env.TRACE_BROWSER_EXECUTABLE}:{})});
 const page=await browser.newPage({viewport:{width:1280,height:900}});
 page.on('pageerror',e=>errors.push(e.message));
 async function call(name,data={}){
  const response=await page.request.post(`${base}/function/${name}`,{data,timeout:60000});
  assert.equal(response.ok(),true);const body=await response.json();assert.equal(body.ok,true,JSON.stringify(body.error));return body.data.result;
 }
 try {
  const loaded=await call('load_corpus');const cid=loaded.incident_id;
  const again=await call('load_corpus');assert.equal(again.incident_id,cid);assert.deepEqual(again.created,{});
  let snap=await call('get_dashboard',{incident_id:cid});
  assert.equal(snap.is_corpus,true);assert.equal(snap.located_reports,1356);assert.equal(snap.unlocated_reports,2244);
  assert.equal(snap.place_counts.length,170);assert.equal(snap.alerts.length,0);
  const groups=new Map();
  for(const row of snap.place_counts){
   const key=JSON.stringify([row.longitude,row.latitude]);
   if(!groups.has(key))groups.set(key,{report_count:0,missing:0,safe:0,other:0});
   for(const field of ['report_count','missing','safe','other'])groups.get(key)[field]+=row[field];
  }
  assert.equal(groups.size,4);assert.equal([...groups.values()].reduce((n,g)=>n+g.report_count,0),1356);
  pass('real persisted corpus imports idempotently with 1356 located / 2244 unlocated reports and no alerts');
  await page.goto(base);
  await page.getByRole('group',{name:'Choose an incident',exact:true}).getByRole('button',{name:/Bhote Koshi exercise corpus/}).click();
  await page.getByText('1356 reports with a location, clustered at 4 settlements; 2244 reports have no verified location.',{exact:true}).waitFor();
  const list=page.getByLabel('Busiest report settlements',{exact:true});
  await page.getByRole('button',{name:/^Kodari · \d+ reports$/}).waitFor();
  assert.equal(await list.getByRole('button').count(),4);
  assert.equal(await page.getByText(/Pin colour follows linked people's current reports/).count(),0);
  assert.equal(await page.getByRole('button',{name:/^Inspect /}).count(),0);
  const rendered=await page.evaluate(async(cid)=>{
   const {aggregate_places}=await import('/compiled/features/map/Density.js');
   const response=await fetch('/function/get_dashboard',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({incident_id:cid})});
   const body=await response.json();return aggregate_places(body.data.result.place_counts);
  },cid);
  for(const row of rendered) assert.deepEqual({report_count:row.report_count,missing:row.missing,safe:row.safe,other:row.other},groups.get(row.key));
  for(const button of await list.getByRole('button').all()){
   await button.click();const text=await page.getByLabel('Settlement report counts',{exact:true}).innerText();
   const match=text.match(/(\d+) reports · (\d+) missing · (\d+) safe · (\d+) other/);assert.ok(match);
   assert.equal(Number(match[1]),Number(match[2])+Number(match[3])+Number(match[4]));
  }
  pass('real incident selector renders four corpus settlement groups and correct source-status totals');
  await page.setViewportSize({width:375,height:812});await page.waitForTimeout(300);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth),375);
  if(process.env.TRACE_CORPUS_SCREENSHOT)await page.screenshot({path:process.env.TRACE_CORPUS_SCREENSHOT,fullPage:true});
  pass('real corpus caption, legends and settlement details fit 375px');
  await call('reset_demo');snap=await call('get_dashboard',{incident_id:cid});
  assert.equal(snap.located_reports,1356);assert.equal(snap.unlocated_reports,2244);assert.equal(snap.alerts.length,0);
  await page.getByRole('button',{name:'Maya story (demo)',exact:true}).click();
  await page.getByRole('button',{name:'Inspect Bhote Koshi Bridge · Missing',exact:true}).waitFor();
  await page.getByLabel('Reported places',{exact:true}).getByRole('button',{name:/^Bhote Koshi Bridge ·/}).click();
  assert.match(await page.getByLabel('Location evidence',{exact:true}).innerText(),/Nepal Police Demo/);
  pass('Maya reset leaves corpus counts intact and returns to cited demo pins');
  assert.deepEqual(errors,[]);console.log(JSON.stringify({real_corpus_checks:checks.length,browser_errors:errors,checks},null,2));
 }finally{await browser.close()}
})().catch(error=>{console.error(error);process.exitCode=1});
