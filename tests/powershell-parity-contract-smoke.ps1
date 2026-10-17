#Requires -Version 7.0
# Offline parity contract; temporary data only, no GitHub Actions.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$Templates=Join-Path $Root 'templates'
$Utf8=[Text.UTF8Encoding]::new($false)
$Sites=Join-Path ([IO.Path]::GetTempPath()) ('zeta-parity-'+[guid]::NewGuid().ToString('N'))
try {
 [void](New-Item -ItemType Directory -Path (Join-Path $Sites 'demo') -Force)
 . (Join-Path $Root 'lib/powershell/Core.ps1')
 $tokens=$null;$parseErrors=$null
 [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'lib/powershell/Workspace.ps1'),[ref]$tokens,[ref]$parseErrors)
 if($parseErrors.Count -gt 0){throw "Workspace parser errors: $($parseErrors -join '; ')"}
 . (Join-Path $Root 'lib/powershell/Workspace.ps1')
 $config=Join-Path $Sites 'demo/config.yaml'
 Save $config @'
site:
  title: "Original"
  description: "Description"
  author: "QA"
  language: "en"
  url: "https://example.org"
  custom: "preserved"
theme:
  name: "zen"
  pandoc_theme: "zenburn"
build:
  content_dir: "posts"
  output_dir: "public"
  blog: false
  custom: "also preserved"
'@
 function Ask([string]$title,[string]$fallback='') { return $fallback }
 function SelectItem([string]$title,[string[]]$items,[string]$fallback='') { return $fallback }
 function Dashboard {}
 EditSite 'demo'
 $yaml=[IO.File]::ReadAllText($config)
 foreach($expected in @('custom: "preserved"','custom: "also preserved"','blog: false','content_dir: "posts"')){
  if(-not $yaml.Contains($expected)){throw "EditSite lost configuration: $expected"}
 }
 $css=@(Styles 'zen' (Join-Path $Sites 'demo') '')
 $actual=@(for($i=0;$i -lt $css.Count;$i++){if($css[$i] -eq '-V'){$css[$i+1]}})
 $expectedCommon=@('normalize.css')+@(Get-ChildItem (Join-Path $Templates 'common/styles') -Filter '*.css' -File | Where-Object Name -ne 'normalize.css' | Sort-Object Name | ForEach-Object Name)
 $expectedNames=$expectedCommon+@(Get-ChildItem (Join-Path $Templates 'zen/styles') -Filter '*.css' -File | Sort-Object Name | ForEach-Object Name)
 $expected=@($expectedNames | ForEach-Object {"css=styles/$_"})
 if(($actual -join '|') -ne ($expected -join '|')){throw "CSS cascade mismatch: $($actual -join ', ') "}
 function Get-ZetaHighlightStyles { @('zenburn') }
 function Build([string]$name) {}
 function Read-Host { throw 'Fully specified theme change prompted unexpectedly' }
 ThemeSite 'demo' 'zen' 'zenburn'
 Write-Host '[OK] PowerShell parity: YAML preserved, CSS order, noninteractive theme change.'
} finally {
 if(Test-Path $Sites){Remove-Item -LiteralPath $Sites -Recurse -Force}
}
