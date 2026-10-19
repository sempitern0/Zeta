#Requires -Version 7.0
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$folder=Join-Path ([IO.Path]::GetTempPath()) ('zeta-pub-'+[guid]::NewGuid().ToString('N'))
$utf8=[Text.UTF8Encoding]::new($false)
try{
 [void](New-Item -ItemType Directory -Path (Join-Path $folder 'about') -Force)
 $homeHtml='<html lang="en"><head><title>Home</title><meta name="description" content="Home"><link rel="canonical" href="https://example.org/"></head><body><a href="about/">About</a></body></html>'
 $about='<html lang="en"><head><title>About</title><meta name="description" content="About"><link rel="canonical" href="https://example.org/about/"></head><body><a href="../index.html">Home</a></body></html>'
 $xml='<urlset><url><loc>https://example.org/</loc></url><url><loc>https://example.org/about/</loc></url></urlset>'
 [IO.File]::WriteAllText((Join-Path $folder 'index.html'),$homeHtml,$utf8)
 [IO.File]::WriteAllText((Join-Path $folder 'about/index.html'),$about,$utf8)
 [IO.File]::WriteAllText((Join-Path $folder 'sitemap.xml'),$xml,$utf8)
 $filter=Join-Path $root 'templates/common/filters/doctor-public.lua'
 function Check{
  $temp=[IO.Path]::GetTempFileName()
  try{
   $lines=@('' | & pandoc -f markdown -t plain "-o" $temp "--lua-filter=$filter" "-Mzeta_doctor_output=$folder" '-Mzeta_doctor_url=https://example.org' 2>&1)
   if($LASTEXITCODE -ne 0){throw "Pandoc filter failed: $lines"}
   return ($lines -join [Environment]::NewLine)
  }finally{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}
 }
 if((Check) -notmatch 'OUTPUT_CHECKED'){throw 'No HTML inspected'}
 [IO.File]::WriteAllText((Join-Path $folder 'index.html'),$homeHtml.Replace('href="about/"','href="missing/"'),$utf8)
 if((Check) -notmatch 'BROKEN_OUTPUT_LINK'){throw 'Broken output link missed'}
 [IO.File]::WriteAllText((Join-Path $folder 'index.html'),$homeHtml,$utf8)
 [IO.File]::WriteAllText((Join-Path $folder 'about/index.html'),$about.Replace('https://example.org/about/','https://example.org/wrong/'),$utf8)
 if((Check) -notmatch 'CANONICAL'){throw 'Canonical mismatch missed'}
 [IO.File]::WriteAllText((Join-Path $folder 'about/index.html'),$about,$utf8)
 [IO.File]::WriteAllText((Join-Path $folder 'sitemap.xml'),$xml.Replace('</urlset>','<url><loc>https://example.org/missing/</loc></url></urlset>'),$utf8)
 if((Check) -notmatch 'SITEMAP_MISSING'){throw 'Missing sitemap route missed'}
 Write-Host '[OK] PowerShell published HTML Doctor filter'
}finally{Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue}
