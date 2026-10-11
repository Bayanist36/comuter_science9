param(
  [string]$DeckPath = 'C:\Users\Владимир\Documents\Gramax\default\comuter_science9\Presentation\Презентация 2.html',
  [string]$OutDir   = 'C:\Users\Владимир\Documents\Gramax\default\comuter_science9\.preview'
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$h = Get-Content -Raw -Encoding UTF8 -Path $DeckPath

$audit = @'
<style>.reveal .slides>section{height:720px !important}</style>
<script>
(function(){
  const sleep=ms=>new Promise(r=>setTimeout(r,ms));
  function geom(wrap){
    const out=[];
    (function walk(el){
      for(const ch of el.children){
        if(!(ch instanceof HTMLElement)) continue;
        if(ch.tagName==='ASIDE') continue;
        if(ch.classList.contains('ghost')) continue;
        const cs=getComputedStyle(ch);
        if(cs.position==='absolute'||cs.position==='fixed') continue;
        const h=ch.offsetHeight;
        if(!isFinite(h)||h<1) continue;
        const rec={sel:(typeof ch.className==='string'&&ch.className.trim()?'.'+ch.className.trim().split(/\s+/).join('.'):'<'+ch.tagName.toLowerCase()+'>'),
                   bottom:ch.offsetTop+h, h:h};
        if(ch.clientHeight>0 && ch.scrollHeight>ch.clientHeight+2 && cs.overflow!=='visible')
          rec.inner=ch.scrollHeight+'/'+ch.clientHeight;
        out.push(rec);
        walk(ch);
      }
    })(wrap);
    return out;
  }
  async function run(){
    await sleep(2000);
    if(typeof Reveal==='undefined'){ document.getElementById('x').textContent='AUDIT:'+JSON.stringify([{id:'ERR',avail:0,maxb:0,delta:0,inner:['Reveal не загрузился'],lowest:[]}]); return; }
    const n=Reveal.getTotalSlides(), res=[];
    for(let i=0;i<n;i++){
      Reveal.slide(i); await sleep(700);
      const s=Reveal.getCurrentSlide();
      const wrap=s.querySelector('.wrap');
      if(!wrap){ res.push({id:s.id, avail:0, maxb:0, delta:0, inner:['НЕТ .wrap'], lowest:[]}); continue; }
      const avail=wrap.clientHeight;
      const g=geom(wrap);
      const maxb=g.reduce((m,x)=>Math.max(m,x.bottom),0);
      res.push({id:s.id, avail:avail, maxb:maxb, delta:maxb-avail,
        inner:g.filter(x=>x.inner).map(x=>x.sel+' '+x.inner),
        lowest:g.slice().sort((a,b)=>b.bottom-a.bottom).slice(0,4).map(x=>x.sel+'@'+x.bottom)});
    }
    document.getElementById('x').textContent='AUDIT:'+JSON.stringify(res);
  }
  window.addEventListener('load',run);
})();
</script>
<div id="x"></div>
'@

$inv = $h -replace '(?s)(</body>)', ($audit + "`n" + '$1')
$auditFile = Join-Path $OutDir 'deck-audit.html'
Set-Content -Path $auditFile -Value $inv -Encoding UTF8

$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$udd = Join-Path $env:TEMP ('dsh-chrome-audit-' + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force -Path $udd | Out-Null
$url = 'file:///' + ($auditFile -replace '\\','/')
$domOut = Join-Path $OutDir 'dom-audit.txt'

$p = Start-Process -FilePath $chrome -ArgumentList @(
  '--headless=new', "--user-data-dir=$udd", '--no-first-run', '--disable-gpu',
  '--window-size=1280,720', '--virtual-time-budget=120000', '--dump-dom', $url
) -RedirectStandardOutput $domOut -RedirectStandardError ($domOut + '.err') -PassThru -Wait

$txt = Get-Content -Raw -Encoding UTF8 -Path $domOut
$m = [regex]::Match($txt, 'AUDIT:(\[.*?\])</div>')
if (-not $m.Success) {
  Write-Output "NO AUDIT DATA (chrome exit=$($p.ExitCode), size=$($txt.Length))"
  if ($txt.Length -lt 400) { Write-Output $txt }
  Get-Content ($domOut + '.err') -Tail 15 -ErrorAction SilentlyContinue
  exit 2
}
$j = $m.Groups[1].Value | ConvertFrom-Json
Write-Output "Слайдов: $($j.Count)  (avail = высота .wrap, maxb = низ последнего блока, delta = перебор(+)/запас(-))"
foreach ($r in $j) {
  $flag = if ($r.delta -gt 0) { "ПЕРЕПОЛНЕНИЕ +$($r.delta)px" } elseif ($r.delta -lt -110) { "много запаса $($r.delta)px" } else { 'ok' }
  Write-Output ("{0,-12} avail={1,-5} maxb={2,-5} delta={3,-6} {4}" -f $r.id, $r.avail, $r.maxb, $r.delta, $flag)
  if ($r.inner -and $r.inner.Count) { Write-Output ("      обрезано внутри: " + ($r.inner -join '; ')) }
  if ($r.delta -gt 0) { Write-Output ("      нижние блоки: " + ($r.lowest -join '; ')) }
}
