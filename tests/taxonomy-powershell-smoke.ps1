#Requires -Version 7.0
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$dir=Join-Path ([IO.Path]::GetTempPath()) ('zeta-tax-'+[guid]::NewGuid().ToString('N'))
$utf8=[Text.UTF8Encoding]::new($false)
try{
 if(-not (Get-Command pandoc -ErrorAction SilentlyContinue)){throw 'Pandoc required'}
 [void](New-Item -ItemType Directory -Force -Path (Join-Path $dir 'posts/2026'))
 foreach($name in @('one','two','three')){
  $html='<html lang="en"><head><title>'+$name+'</title></head><body><main><h1>'+$name+'</h1></main></body></html>'
  [IO.File]::WriteAllText((Join-Path $dir "posts/2026/$name.html"),$html,$utf8)
 }
 [void](New-Item -ItemType Directory -Path (Join-Path $dir 'styles') -Force)
 [IO.File]::WriteAllText((Join-Path $dir 'styles/zeta-pages.css'),'body.zeta-static-page{display:flex}',$utf8)
 [IO.File]::WriteAllText((Join-Path $dir 'styles/00-theme-contract.css'),'body.zeta-static-page{background:#101421}',$utf8)
 [IO.File]::WriteAllText((Join-Path $dir 'index.html'),'<html><head><link rel="stylesheet" href="styles/zeta-pages.css"><link rel="stylesheet" href="styles/00-theme-contract.css"></head><body><nav aria-label="Primary navigation"><a href="index.html">Home</a> <a href="about/">About</a></nav></body></html>',$utf8)
 [IO.File]::WriteAllText((Join-Path $dir 'sitemap.xml'),'<urlset><url><loc>https://example.org/</loc></url></urlset>',$utf8)
 $rows=@(
  (@('posts/2026/one.html','category','godot','Godot') -join [char]9)
  (@('posts/2026/one.html','tag','plugins','Plugins') -join [char]9)
  (@('posts/2026/two.html','category','godot','Godot') -join [char]9)
  (@('posts/2026/three.html','tag','plugins','Plugins') -join [char]9)
 )
 [IO.File]::WriteAllText((Join-Path $dir '.zeta-taxonomy.tsv'),($rows -join [Environment]::NewLine),$utf8)
 $filter=Join-Path $root 'templates/common/filters/taxonomies.lua'
 $temporary=[IO.Path]::GetTempFileName()
 try{
  $null=@('' | & pandoc '-f' 'markdown' '-t' 'plain' "--lua-filter=$filter" "-Mzeta_taxonomy_output=$dir" '-Mzeta_taxonomy_url=https://example.org' '-Mzeta_taxonomy_title=Demo' '-Mzeta_taxonomy_language=en' '-o' $temporary)
  if($LASTEXITCODE -ne 0){throw 'Taxonomy filter failed'}
 }finally{Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue}
 foreach($item in @('categories/index.html','categories/godot/index.html','tags/index.html','tags/plugins/index.html')){
  if(!(Test-Path (Join-Path $dir $item))){throw "Missing $item"}
 }
 $archive=[IO.File]::ReadAllText((Join-Path $dir 'tags/plugins/index.html'))
 if(-not $archive.Contains('href="../../styles/00-theme-contract.css"')){throw 'Missing theme CSS in tag archive'}
 if(-not $archive.Contains('href="../../about/"')){throw 'Missing global navigation in tag archive'}
 $post=[IO.File]::ReadAllText((Join-Path $dir 'posts/2026/one.html'))
 if(!$post.Contains('Related articles')){throw 'Related article links missing'}
 Write-Host '[OK] PowerShell taxonomy validation' -ForegroundColor Green
}finally{Remove-Item -LiteralPath $dir -Force -Recurse -ErrorAction SilentlyContinue}
