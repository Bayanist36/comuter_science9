// Минимальный DOM/библиотечный стаб, чтобы выполнить скрипт дека и поймать рантайм-ошибки.
import fs from 'node:fs';

const file = process.argv[2];
const html = fs.readFileSync(file, 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
if (scripts.length !== 1) throw new Error('ожидался один инлайн-скрипт, найдено: ' + scripts.length);

const mkEl = (tag = 'div') => {
  const el = {
    tag, dataset: {}, style: {}, textContent: '', node: () => el,
    classList: { add(){}, remove(){}, contains(){return false} },
    getTotalLength: () => 100,
    setAttribute(){}, getAttribute(){return null}, appendChild(){},
  };
  return el;
};

const els = [];
const doc = {
  body: mkEl('body'),
  documentElement: mkEl('html'),
  getElementById: (id) => { const e = mkEl('section'); e.id = id; return e; },
  querySelector: () => mkEl(),
  querySelectorAll: () => Array.from({length: 3}, () => mkEl()),
  addEventListener(){}, createElement: mkEl,
};

// универсальный прокси-объект: любое свойство — функция, возвращающая себя
function chain(name = 'root') {
  const target = function () { return proxy; };
  const proxy = new Proxy(target, {
    get(t, prop) {
      if (prop === 'node') return () => proxy;
      if (prop === 'symbol' || prop === Symbol.toPrimitive) return () => '[' + name + ']';
      if (prop === 'then') return undefined;             // не тогдабельный
      if (prop === 'length') return 0;
      if (prop === 'style' || prop === 'dataset') return {};
      if (!(prop in t)) t[prop] = undefined;
      return chain(name + '.' + String(prop));
    },
    set(t, prop, v) { t[prop] = v; return true; },
    apply() { return proxy; },
    has() { return true; },
  });
  return proxy;
}

const SVG = chain('SVG');
const gsap = chain('gsap');
gsap.timeline = () => chain('timeline');
const d3 = chain('d3');
d3.select = () => chain('select');
d3.scaleLinear = () => chain('scaleLinear');
d3.scaleLog = () => chain('scaleLog');
d3.pie = () => { const f = () => [{startAngle:0,endAngle:1,data:{v:60}},{startAngle:1,endAngle:2,data:{v:40}}]; Object.assign(f, {sort:f,padAngle:f,value:f}); return f; };
d3.arc = () => { const f = () => 'M0'; Object.assign(f, {innerRadius:f,outerRadius:f,centroid:() => [0,0]}); return f; };
d3.line = () => { const f = () => ({node:()=>({getTotalLength:()=>100})}); Object.assign(f,{x:f,y:f,curve:f}); return f; };
d3.area = () => { const f = () => ({node:()=>({getTotalLength:()=>100})}); Object.assign(f,{x:f,y0:f,y1:f,curve:f}); return f; };
d3.interpolate = () => () => 'M0';
d3.easeCubicOut = chain('easeCubicOut');
const Reveal = chain('Reveal');
Reveal.initialize = () => Promise.resolve();
Reveal.on = (ev, cb) => { if (cb) cb({currentSlide: doc.getElementById('s-title'), previousSlide: doc.getElementById('s-ib')}); };

globalThis.window = {
  matchMedia: () => ({matches:false}), addEventListener(){}, innerWidth:1280, innerHeight:720,
  __revealCDNFailed: false,
};
globalThis.document = doc;
globalThis.SVG = SVG; globalThis.gsap = gsap; globalThis.d3 = d3;
globalThis.Reveal = Reveal; globalThis.RevealNotes = chain('notes'); globalThis.RevealZoom = chain('zoom');

let failed = 0;
try {
  // выполняем скрипт в общем контексте
  const fn = new Function(scripts[0]);
  fn.call(globalThis);
  console.log('OK: скрипт выполнен без ошибок');
} catch (e) {
  failed = 1;
  console.error('RUNTIME ERROR:', e && e.stack ? e.stack : e);
}
await new Promise(r => setTimeout(r, 60));
process.exit(failed);
