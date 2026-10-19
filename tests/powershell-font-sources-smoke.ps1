#Requires -Version 7.0
# Offline install regression for the replacement variable TrueType fonts.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$Templates=Join-Path $Root 'templates'
$Utf8=[Text.UTF8Encoding]::new($false)
. (Join-Path $Root 'lib/powershell/Core.ps1')
. (Join-Path $Root 'lib/powershell/Workspace.ps1')
$temp=Join-Path ([IO.Path]::GetTempPath()) ('zeta-font-sources-'+[guid]::NewGuid().ToString('N'))
try {
 # Isolate the font cache as well as the site from the user's workspace.
 $Root=$temp
 $Sites=Join-Path $temp 'sites'
 $site=Join-Path $Sites 'example'
 [void](New-Item -ItemType Directory -Path $site -Force)
 Save (Join-Path $site 'config.yaml') "site:`n  title: Example"
 $sources=Get-ZetaFontSources
 foreach($choice in @('cascadia','fira')){
  $spec=$sources[$choice]
  $cache=Join-Path $Root ".zeta-cache/fonts/$($spec.id)"
  [void](New-Item -ItemType Directory -Path $cache -Force)
  foreach($entry in $spec.files){
   if($entry[3] -notmatch '^https://raw.githubusercontent.com/google/fonts/[a-f0-9]{40}/ofl/' -or !$entry[0].EndsWith('.ttf')){throw "Unpinned or missing font source: $choice"}
   [IO.File]::WriteAllBytes((Join-Path $cache $entry[0]),[byte[]](0,1,0,0))
  }
  Save (Join-Path $cache 'LICENSE.txt') 'OFL test fixture'
  Install-ZetaSiteFont 'example' $choice
  $css=[IO.File]::ReadAllText((Join-Path $site 'styles/90-font.css'))
  if(!$css.Contains('format("truetype")') -or $css.Contains('format("woff2")')){throw "Incorrect font format: $choice"}
  if(!$css.Contains("font-weight: $($spec.files[0][2]);")){throw "Variable weights lost: $choice"}
  foreach($entry in $spec.files){
   if(!(Test-Path (Join-Path $site "assets/fonts/$($spec.id)/$($entry[0])"))){throw "Font asset missing: $choice"}
  }
 }
 Write-Host '[OK] Cascadia and Fira variable fonts, asset paths and CSS formats.'
}finally{
 if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
