#Requires -Version 7.0
# No external services or GitHub Actions; tests the shared filter.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$stage=Join-Path ([IO.Path]::GetTempPath()) ('zeta-seo-'+[guid]::NewGuid().ToString('N'))
$utf8=[Text.UTF8Encoding]::new($false)
try {
 if(-not (Get-Command pandoc -ErrorAction SilentlyContinue)){throw 'Pandoc required'}
 [void](New-Item -ItemType Directory -Force -Path (Join-Path $stage 'about'),(Join-Path $stage 'posts/2026'),(Join-Path $stage 'assets'))
 $home='<!doctype html><html lang="en"><head><title>Example &amp; Zeta</title><meta name="description" content="Homepage"><meta name="description" content="duplicate"><link rel="canonical" href="https://old.example/"></head><body>Home</body></html>'
 $about='<!doctype html><html lang="en"><head><title>About</title></head><body>About</body></html>'
 $post='<!doctype html><html lang="en"><head><title>First article</title><meta name="description" content="Individual summary"></head><body><time datetime="2026-10-14">14 October</time></body></html>'
 [IO.File]::WriteAllText((Join-Path $stage 'index.html'),$home,$utf8)
 [IO.File]::WriteAllText((Join-Path $stage 'about/index.html'),$about,$utf8)
 [IO.File]::WriteAllText((Join-Path $stage 'posts/2026/first.html'),$post,$utf8)
 [IO.File]::WriteAllText((Join-Path $stage 'assets/cover.svg'),'<svg xmlns="http://www.w3.org/2000/svg"></svg>',$utf8)
 $filter=Join-Path $root 'templates/common/filters/seo-publish.lua'
 function Invoke-TestSeo {
  $output=[IO.Path]::GetTempFileName()
  try {
   $args=@('-f','markdown','-t','plain',("--lua-filter=$filter"),'-M',("zeta_seo_output=$stage"),'-M','zeta_seo_url=https://example.org/project','-M','zeta_seo_title=Test site','-M','zeta_seo_description=Site description','-M','zeta_seo_image=assets/cover.svg','-o',$output)
   $null=@('' | & pandoc @args)
   if($LASTEXITCODE -ne 0){throw "SEO filter failed with Pandoc exit code $LASTEXITCODE"}
  }finally{Remove-Item -LiteralPath $output -Force -ErrorAction SilentlyContinue}
 }
 Invoke-TestSeo
 $h=[IO.File]::ReadAllText((Join-Path $stage 'index.html'))
 $a=[IO.File]::ReadAllText((Join-Path $stage 'about/index.html'))
 $p=[IO.File]::ReadAllText((Join-Path $stage 'posts/2026/first.html'))
 if(-not $h.Contains('href="https://example.org/project/"')){throw 'Home canonical incorrect'}
 if(-not $a.Contains('href="https://example.org/project/about/"')){throw 'About canonical incorrect'}
 if(-not $p.Contains('href="https://example.org/project/posts/2026/first.html"')){throw 'Post canonical incorrect'}
 if(-not $h.Contains('content="summary_large_image"')){throw 'Social card missing'}
 if(-not $h.Contains('https://example.org/project/assets/cover.svg')){throw 'Social image missing'}
 if(-not $p.Contains('article:published_time" content="2026-10-14"')){throw 'Article date missing'}
 if(-not $h.Contains('og:title" content="Example &amp; Zeta"')){throw 'HTML escape not preserved'}
 if(([regex]::Matches($h,'name="description"')).Count -ne 1){throw 'Duplicate description'}
 if(([regex]::Matches($h,'rel="canonical"')).Count -ne 1){throw 'Duplicate canonical'}
 Invoke-TestSeo
 if([IO.File]::ReadAllText((Join-Path $stage 'index.html')) -cne $h){throw 'SEO output is not idempotent'}
 Write-Host '[OK] PowerShell SEO filter: canonical, social preview, article date, idempotence'
}finally {Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue}
