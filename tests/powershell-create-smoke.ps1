#Requires -Version 7.0
# Offline parity test; does not require Pandoc or GitHub Actions.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repository=Split-Path -Parent $PSScriptRoot
$Root=$repository
$Templates=Join-Path $repository 'templates'
$folder=Join-Path ([IO.Path]::GetTempPath()) ('zeta-create-'+[guid]::NewGuid().ToString('N'))
$Sites=Join-Path $folder 'sites'
$Utf8=[Text.UTF8Encoding]::new($false)
$Force=$false
try{
 [void](New-Item -ItemType Directory -Path $Sites -Force)
 . (Join-Path $Root 'lib/powershell/Dependencies.ps1')
 . (Join-Path $Root 'lib/powershell/Core.ps1')
 . (Join-Path $Root 'lib/powershell/Workspace.ps1')
 function Test-ZetaPandoc {return $false}
 function Install-ZetaPandoc {return $false}
 function Get-ZetaHighlightStyles {return @('zenburn','tango')}
 $script:replies=[Collections.Generic.Queue[string]]::new()
 foreach($v in @('Zeta Test','Test description','QA','es-ES','','https://example.org','organization','tango')){
  $script:replies.Enqueue($v)
 }
 function Read-Host {
  param([string]$Prompt)
  if(!$script:replies.Count){throw "Unexpected prompt: $Prompt"}
  return $script:replies.Dequeue()
 }
 NewSite
 if($script:replies.Count -ne 0){throw 'Wizard did not ask all eight fields'}
 $site=Join-Path $Sites 'zeta-test'
 $yamlText=[IO.File]::ReadAllText((Join-Path $site 'config.yaml'))
 foreach($expectedLine in @('  title: "Zeta Test"','  description: "Test description"','  author: "QA"','  language: "es-ES"','  name: "organization"','  pandoc_theme: "tango"','  content_dir: "posts"','  output_dir: "public"')){
  if(-not (($yamlText -split '\r?\n') -ccontains $expectedLine)){
   throw "YAML writer failed to emit a complete key/value line: $expectedLine"
  }
 }
 $postFiles=@(Get-ChildItem (Join-Path $site 'posts') -Filter '*.md' -File)
 if($postFiles.Count -ne 2){throw "Expected two Markdown showcases, got $($postFiles.Count)"}
 foreach($example in @('markdown-showcase','code-showcase')){
  $path=Join-Path (Join-Path $site 'posts') "$(Get-Date -Format yyyy-MM-dd)-zeta-$example.md"
  if(-not (Test-Path -LiteralPath $path)){throw "Missing shared example: $example"}
  $text=[IO.File]::ReadAllText($path)
  foreach($line in @('author: "QA"',('date: "'+(Get-Date -Format yyyy-MM-dd)+'"'))){
   if(-not (($text -split '\r?\n') -ccontains $line)){throw "Malformed $example metadata: $line"}
  }
  if($example -eq 'markdown-showcase' -and ($text -notmatch '## Grid table' -or $text -notmatch '\[\^zeta\]')){
   throw 'Markdown showcase lost tables or footnotes'
  }
  if($example -eq 'code-showcase' -and ($text -notmatch '```bash' -or $text -notmatch '```python')){
   throw 'Code showcase lost syntax highlighting examples'
  }
  if(Get-Command pandoc -ErrorAction SilentlyContinue){
   $null=& pandoc --from markdown --to html $path
   if($LASTEXITCODE -ne 0){throw "Pandoc cannot parse $example"}
  }
 }
 $c=Config 'zeta-test'
 if($c.title -ne 'Zeta Test' -or $c.language -ne 'es-ES' -or
   $c.highlight -ne 'tango' -or $c.theme -ne 'organization' -or
   $c.description -ne 'Test description' -or $c.author -ne 'QA'){
  throw 'Creation fields were not saved'
 }
 if(@(SiteNames) -notcontains 'zeta-test'){throw 'Created site not discovered'}
 $script:replies.Clear()
 foreach($v in @('Zeta Test','','','en','')){$script:replies.Enqueue($v)}
 $failed=$false
 try{NewSite}catch{$failed=$true}
 if(!$failed){throw 'Duplicate site must be rejected'}
 if(!(Test-Path (Join-Path $site 'config.yaml'))){throw 'Duplicate attempt modified original'}
 # With Pandoc available, creating a site must also produce the public directory.
 function Test-ZetaPandoc {return $true}
 function Build([string]$name) {
  $c=Config $name
  if($c.content -ne 'posts' -or $c.output -ne 'public'){throw 'Invalid site paths during build'}
  $target=Join-Path (SiteDir $name) 'public/index.html'
  Save $target '<!doctype html><title>Generated</title>'
 }
 $script:replies.Clear()
 foreach($v in @('Built Site','A built example','QA','en','','https://example.org','zen','zenburn')){
  $script:replies.Enqueue($v)
 }
 NewSite
 if($script:replies.Count -ne 0){throw 'Build-enabled wizard missed a prompt'}
 if(-not (Test-Path (Join-Path $Sites 'built-site/public/index.html'))){throw 'Creation did not run the HTML build'}
 Write-Host '[OK] Eight creation prompts, correctly formatted YAML, automatic build and duplicate protection.' -ForegroundColor Green
}finally{Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue}
