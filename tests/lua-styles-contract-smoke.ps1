#Requires -Version 7.0
# Native PowerShell regression for the shared Pandoc Lua publication contract.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$filters = Join-Path $root 'templates/common/filters'
$folder = Join-Path ([IO.Path]::GetTempPath()) ('zeta-lua-contract-' + [guid]::NewGuid().ToString('N'))
$utf8 = [Text.UTF8Encoding]::new($false)
try {
 if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) { throw 'Pandoc is required' }
 foreach ($file in @(Get-ChildItem -LiteralPath $filters -Filter '*.lua' -File)) {
  $source = $file.FullName.Replace('\','/')
  $null = & pandoc lua -e "assert(loadfile([==[$source]==]))"
  if ($LASTEXITCODE -ne 0) { throw "Lua syntax error: $source" }
 }
 [void](New-Item -ItemType Directory -Force -Path (Join-Path $folder 'styles'),(Join-Path $folder 'tags/plugins'))
 [IO.File]::WriteAllText((Join-Path $folder 'styles/zeta-pages.css'),'body.zeta-static-page{display:flex}',$utf8)
 [IO.File]::WriteAllText((Join-Path $folder 'styles/00-theme-contract.css'),'body.zeta-static-page{--page-bg:#101421}',$utf8)
 $index = '<!doctype html><html lang="en"><head><title>Home</title><meta name="description" content="Home"><link rel="canonical" href="https://example.org/"><link rel="stylesheet" href="styles/zeta-pages.css"><link href="styles/00-theme-contract.css" rel="stylesheet"></head><body class="zeta-static-page"><main>Home</main></body></html>'
 $archive = '<!doctype html><html lang="en"><head><title>Plugins</title><meta name="description" content="Posts about plugins"><link rel="canonical" href="https://example.org/tags/plugins/"><link rel="stylesheet" href="../../styles/zeta-pages.css"><link rel="stylesheet" href="../../styles/00-theme-contract.css"></head><body class="zeta-static-page zeta-tax-page"><main>Plugins</main></body></html>'
 $archivePath = Join-Path $folder 'tags/plugins/index.html'
 [IO.File]::WriteAllText((Join-Path $folder 'index.html'),$index,$utf8)
 [IO.File]::WriteAllText($archivePath,$archive,$utf8)
 [IO.File]::WriteAllText((Join-Path $folder 'sitemap.xml'),'<urlset><url><loc>https://example.org/</loc></url><url><loc>https://example.org/tags/plugins/</loc></url></urlset>',$utf8)
 $filter = Join-Path $filters 'doctor-public.lua'
 function Invoke-LocalDoctor {
  $tmp = [IO.Path]::GetTempFileName()
  try {
   $report = @('' | & pandoc -f markdown -t plain "--lua-filter=$filter" '-M' "zeta_doctor_output=$folder" '-M' 'zeta_doctor_url=https://example.org' '-o' $tmp 2>&1)
   if ($LASTEXITCODE -ne 0) { throw "Pandoc doctor failed: $report" }
   return ($report -join [Environment]::NewLine)
  } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
 }
 $result = Invoke-LocalDoctor
 if (-not $result.Contains('ZETA_DOCTOR|OK|OUTPUT_CHECKED|2 HTML file(s) inspected')) { throw 'Missing successful audit result' }
 if ($result.Contains('ZETA_DOCTOR|FAIL|')) { throw "Valid site rejected: $result" }
 [IO.File]::WriteAllText($archivePath,$archive.Replace('<link rel="stylesheet" href="../../styles/00-theme-contract.css">',''),$utf8)
 $result = Invoke-LocalDoctor
 if (-not $result.Contains('ZETA_DOCTOR|FAIL|THEME_STYLES|tags/plugins/index.html: missing stylesheet styles/00-theme-contract.css')) { throw 'Missing stylesheet went undetected' }
 [IO.File]::WriteAllText($archivePath,$archive.Replace('href="../../styles/00-theme-contract.css"','href="../styles/00-theme-contract.css"'),$utf8)
 $result = Invoke-LocalDoctor
 if (-not $result.Contains('ZETA_DOCTOR|FAIL|BROKEN_OUTPUT_LINK')) { throw 'Broken stylesheet link went undetected' }
 if (-not $result.Contains('ZETA_DOCTOR|FAIL|THEME_STYLES')) { throw 'Incorrect stylesheet depth went undetected' }
 Write-Host '[OK] Lua syntax and theme stylesheet checks.' -ForegroundColor Green
} finally {
 if (Test-Path -LiteralPath $folder) { Remove-Item -LiteralPath $folder -Recurse -Force }
}
