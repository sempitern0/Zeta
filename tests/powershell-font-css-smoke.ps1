#Requires -Version 7.0
# Offline test for optional font CSS and failed theme changes. No downloads.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$Templates=Join-Path $Root 'templates'
$Utf8=[Text.UTF8Encoding]::new($false)
$temp=Join-Path ([IO.Path]::GetTempPath()) ('zeta-font-css-'+[guid]::NewGuid().ToString('N'))
$Sites=Join-Path $temp 'sites'
$cache=Join-Path $Root '.zeta-cache/fonts/JetBrainsMono'
$files=@('JetBrainsMono-Regular.woff2','JetBrainsMono-Bold.woff2','LICENSE.txt')
$existing=@{}
try {
 [void](New-Item -ItemType Directory -Force -Path $Sites,$cache)
 . (Join-Path $Root 'lib/powershell/Core.ps1')
 . (Join-Path $Root 'lib/powershell/Workspace.ps1')
 $site=Join-Path $Sites 'example'
 [void](New-Item -ItemType Directory -Force -Path $site)
 $config=Join-Path $site 'config.yaml'
 Save $config @'
site:
  title: "Example"
  custom: "keep"
theme:
  name: "zen"
  pandoc_theme: "zenburn"
build:
  content_dir: "posts"
  output_dir: "public"
'@
 foreach($file in $files){
  $path=Join-Path $cache $file
  if(Test-Path -LiteralPath $path){$existing[$file]=[IO.File]::ReadAllBytes($path)}
  else{$existing[$file]=$null}
  if($null -eq $existing[$file]){[IO.File]::WriteAllBytes($path,[byte[]](1,2,3))}
 }
 Install-ZetaSiteFont 'example' 'jetbrains'
 $css=Join-Path $site 'styles/90-font.css'
 $text=[IO.File]::ReadAllText($css)
 if($text -notmatch '@font-face \{ font-family: "JetBrains Mono";' -or $text -notmatch ':root \{ --font-mono: "JetBrains Mono"' -or $text -match '\{\{'){
  throw "Font CSS formatting regression: $text"
 }
 if(([regex]::Matches($text,'@font-face')).Count -ne 2){throw 'JetBrains Mono must produce two font-face rules'}
 if(-not (Test-Path (Join-Path $site 'assets/fonts/JetBrainsMono/LICENSE.txt'))){throw 'Font license missing'}
 # Repeat the exact interactive Aurora + espresso + Yes flow, using cached assets.
 function Get-ZetaHighlightStyles { @('espresso','zenburn') }
 $script:replies=[Collections.Generic.Queue[string]]::new()
 foreach($answer in @('aurora','espresso','y')){$script:replies.Enqueue($answer)}
 function Read-Host { param([string]$Prompt) if(!$script:replies.Count){throw "Unexpected prompt: $Prompt"};return $script:replies.Dequeue() }
 function Build([string]$name) {
  $config=Config $name
  if($config.theme -ne 'aurora' -or $config.highlight -ne 'espresso'){throw 'Theme selection incorrect'}
  if(-not (Test-Path (Join-Path (SiteDir $name) 'styles/90-font.css'))){throw 'Font CSS missing on build'}
 }
 function Dashboard {}
 ThemeSite 'example' '' ''
 if($script:replies.Count -ne 0){throw 'Unexpected interactive prompts'}
 $yaml=[IO.File]::ReadAllText($config)
 if(-not $yaml.Contains('custom: "keep"')){throw 'Custom configuration was lost'}
 if(-not $yaml.Contains('name: "aurora"') -or -not $yaml.Contains('pandoc_theme: "espresso"')){throw 'Theme was not saved'}
 # A failed font install must not remove existing assets or alter the configuration.
 $before=[IO.File]::ReadAllBytes($config)
 $beforeCss=[IO.File]::ReadAllBytes($css)
 function Install-ZetaSiteFont([string]$name,[string]$choice){throw 'Simulated font download failure'}
 $script:replies.Enqueue('zen')
 $script:replies.Enqueue('zenburn')
 $script:replies.Enqueue('y')
 $failed=$false
 try{ ThemeSite 'example' '' '' }catch{ $failed=$true; if($_.Exception.Message -ne 'Simulated font download failure'){throw} }
 if(-not $failed){throw 'Expected font failure was not propagated'}
 if([Convert]::ToBase64String($before) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($config))){throw 'Font failure modified configuration'}
 if([Convert]::ToBase64String($beforeCss) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($css))){throw 'Font failure modified CSS'}
 Write-Host '[OK] Optional font CSS, Aurora theme selection and config recovery.'
}finally{
 foreach($file in $files){
  $path=Join-Path $cache $file
  if($existing.ContainsKey($file)){
   if($null -eq $existing[$file]){Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue}
   else{[IO.File]::WriteAllBytes($path,$existing[$file])}
  }
 }
 if(Test-Path $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
