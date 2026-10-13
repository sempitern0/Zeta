# Zeta PowerShell: site, post, fonts, preview, and maintenance.
function Dashboard {
 [void](New-Item -ItemType Directory -Path $Sites -Force)
 $cards=@()
 foreach($name in (SiteNames)){
  $c=Config $name
  $href='./'+$name+'/'+$c.output.Replace('\','/')+'/'
  $cards+='<a href="'+(Escape $href)+'">'+(Escape $c.title)+'</a>'
 }
 $html='<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Zeta workspace</title><style>body{font:1.1rem system-ui;background:#101822;color:white;padding:3rem}a{display:block;margin:1rem;padding:1rem;background:#253548;color:white}</style></head><body><h1>Zeta workspace</h1>'+($cards -join '')+'</body></html>'
 Save (Join-Path $Sites 'index.html') $html
}
function SelectItem([string]$title,[string[]]$items,[string]$fallback=''){
 if($items.Count -eq 0){throw "No choices available for $title"}
 for($i=0;$i -lt $items.Count;$i++){Write-Host ("[{0}] {1}" -f ($i+1),$items[$i])}
 $answer=Read-Host "$title (number or name)"
 if([string]::IsNullOrWhiteSpace($answer)){return $fallback}
 $number=0
 if([int]::TryParse($answer,[ref]$number)){
  if($number -lt 1 -or $number -gt $items.Count){throw "Invalid selection $number"}
  return $items[$number-1]
 }
 foreach($item in $items){if($item -ieq $answer.Trim()){return $item}}
 throw "Unknown choice '$answer'"
}
function Ask([string]$title,[string]$fallback=''){
 $v=Read-Host ("$title [$fallback]")
 if(!$v){return $fallback};return $v
}
function Get-ZetaHighlightStyles {
 $fallback=@('zenburn','pygments','kate','monochrome','breezedark','espresso','haddock','tango')
 if(-not (Get-Command pandoc -ErrorAction SilentlyContinue)){return $fallback}
 try{
  $available=@(& pandoc --list-highlight-styles 2>$null)
  if($LASTEXITCODE -eq 0 -and $available.Count -gt 0){
   return @($available | Where-Object {-not [string]::IsNullOrWhiteSpace($_)} | ForEach-Object {$_.Trim()})
  }
 }catch{
  # Missing or faulty Pandoc must not prevent writing site sources.
 }
 return $fallback
}
function NewSite{
 $title=Ask 'Title' 'My New Blog'
 if([string]::IsNullOrWhiteSpace($title)){throw 'Site title is required'}
 $description=Ask 'Description' 'A static blog built with Zeta'
 $author=Ask 'Author' [Environment]::UserName
 $language=Ask 'Language' 'en'
 if($language -notmatch '^[A-Za-z]{2,3}([_-][A-Za-z0-9]{2,8})*$'){
  throw "Invalid language '$language' (e.g. en, es, es-ES)."
 }
 $defaultSlug=Slug $title
 if(-not $defaultSlug){throw 'Cannot derive a safe slug from the site title'}
 $slug=Ask 'Site slug' $defaultSlug
 $dir=SiteDir $slug
 if(Test-Path -LiteralPath $dir){throw "Site '$slug' already exists. Nothing was overwritten."}
 $url=Ask 'Production URL for sitemap' 'https://example.com'
 if($url -notmatch '^https?://[^\s?#]+$'){throw "Invalid production URL '$url'."}
 $themes=@(Themes)
 if($themes.Count -eq 0){throw 'No compatible themes available in templates/'}
 $theme=SelectItem 'Theme' $themes $(if($themes -contains 'zen'){'zen'}else{$themes[0]})
 $highlight=SelectItem 'Pandoc highlight style' @(Get-ZetaHighlightStyles) 'zenburn'
 $c=@{
  title=$title;description=$description;author=$author;language=$language;
  url=$url.TrimEnd('/');theme=$theme;highlight=$highlight;content='posts';output='public'
 }
 $created=$false
 try{
  [void](New-Item -ItemType Directory -Path (Join-Path $dir 'posts') -Force)
  $created=$true
  Save (Join-Path $dir 'config.yaml') (ConfigText $c)
  $today=Get-Date -Format yyyy-MM-dd
  $sample=@('---','title: "Welcome to Zeta"','author: '+(Quote $c.author),
    'date: '+(Quote $today),'description: "Your first Markdown article"',
    'tags: [zeta, introduction]','---','',
    '# Hello, world','','This is a Markdown article.','','## Next steps','','Edit this file and rebuild the site.')
  Save (Join-Path (Join-Path $dir 'posts') ("{0}-welcome.md" -f $today)) ($sample -join [Environment]::NewLine)
 }catch{
  if($created -and (Test-Path -LiteralPath $dir)){Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue}
  throw
 }
 Write-Host "[OK] Site created: $dir" -ForegroundColor Green
 try{Dashboard}catch{Write-Warning "Workspace index update failed: $($_.Exception.Message)"}
 if(-not (Test-ZetaPandoc)){
  Write-Host 'Site sources are ready; Pandoc is only needed to build HTML.' -ForegroundColor Yellow
  if($IsWindows){[void](Install-ZetaPandoc)}
 }else{Write-Host "Next: .\zeta.ps1 build $slug" -ForegroundColor Cyan}
}
function EditSite([string]$name){
 $c=Config $name
 foreach($key in @('title','description','author','language','url')){$c[$key]=Ask $key $c[$key]}
 if($c.language -notmatch '^[A-Za-z]{2,3}([_-][A-Za-z0-9]{2,8})*$'){
  throw "Invalid language '$($c.language)'."
 }
 if($c.url -notmatch '^https?://[^\s?#]+$'){throw "Invalid production URL '$($c.url)'."}
 $c.url=$c.url.TrimEnd('/')
 $c.theme=SelectItem 'Theme' @(Themes) $c.theme
 $c.highlight=SelectItem 'Pandoc highlight style' @(Get-ZetaHighlightStyles) $c.highlight
 Save (ConfigPath $name) (ConfigText $c)
 Dashboard
 Write-Host "[OK] Configuration updated for $name" -ForegroundColor Green
}
function ThemeSite([string]$name,[string]$theme,[string]$style=''){
 $c=Config $name
 if(!$theme){$theme=SelectItem 'Theme' @(Themes) $c.theme}
 if(@(Themes) -notcontains $theme){throw "Unknown theme '$theme'."}
 if(!$style){$style=SelectItem 'Pandoc highlight style' @(Get-ZetaHighlightStyles) $c.highlight}
 if(@(Get-ZetaHighlightStyles) -notcontains $style){throw "Unknown highlight style '$style'."}
 $c.theme=$theme
 $c.highlight=$style
 Save (ConfigPath $name) (ConfigText $c)
 Build $name
 Dashboard
}
function NewPost([string]$name){
 $c=Config $name
 $title=Ask 'Title';if(!$title){throw 'Title required'}
 $slug=Slug (Ask 'Slug' (Slug $title))
 $date=Get-Date -Format yyyy-MM-dd
 $file=Join-Path (Join-Path (SiteDir $name) $c.content) "$date-$slug.md"
 if((Test-Path $file) -and !$Force){throw 'Article exists'}
 $desc=Ask 'Description' $title
 $tags=Ask 'Tags (comma-separated)' ''
 $body=@('---','title: '+(Quote $title),'author: '+(Quote $c.author),
 'date: '+(Quote $date),'description: '+(Quote $desc),'slug: '+(Quote $slug),
 'tags: []','---','','Write your introduction here.','','## First section','')
 if($tags){
  $body=@($body[0..5])+@('tags:')+@(foreach($t in ($tags -split ',')){if($t.Trim()){'  - '+(Quote $t.Trim())}})+@($body[7..($body.Length-1)])
 }
 Save $file ($body -join [Environment]::NewLine)
 Write-Host "Created $file" -ForegroundColor Green
}
function ListSites{
 foreach($name in (SiteNames)){
  $c=Config $name;$status='draft'
  if(Test-Path (Join-Path (SiteDir $name) "$($c.output)/index.html")){$status='built'}
  Write-Host ("{0,-24} {1,3} posts  {2,-15} {3}" -f $name,(Posts $name).Count,$c.theme,$status)
 }
}
function Clean([string]$name){
 $c=Config $name
 if(!(SafeDir $c.output) -or !(SafeDir $c.content)){throw 'Unsafe output directory'}
 $out=$c.output.Replace('\','/').Trim('/');$input=$c.content.Replace('\','/').Trim('/')
 if($out -eq $input -or $out.StartsWith("$input/") -or $input.StartsWith("$out/")){throw 'Overlapping output and content directories'}
 $p=Join-Path (SiteDir $name) $c.output
 if(Test-Path $p){Remove-Item $p -Recurse -Force}
}
function Preview([string]$name,[int]$serverPort){
 Build $name
 $c=Config $name
 $dir=Join-Path (SiteDir $name) $c.output
 Serve $dir $serverPort
}
function Serve([string]$dir,[int]$serverPort){
 if($serverPort -lt 1 -or $serverPort -gt 65535){throw "Invalid preview port: $serverPort"}
 if(-not (Test-Path -LiteralPath $dir -PathType Container)){
  throw "Cannot serve missing directory: $dir"
 }
 $listener=[Net.HttpListener]::new()
 $listener.Prefixes.Add("http://localhost:$serverPort/")
 $started=$false
 $interactiveConsole=$false
 try{
  try{
   $interactiveConsole=($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected)
  }catch [System.InvalidOperationException]{
   # Windows Terminal, IDE hosts, and redirected input can differ.
  }
  $listener.Start()
  $started=$true
  Write-Host "http://localhost:$serverPort/  (Ctrl+C or Q to stop)" -ForegroundColor Cyan
  $running=$true
  while($running -and $listener.IsListening){
   # A synchronous GetContext() blocks PowerShell's Ctrl+C pipeline stop.
   # Poll an asynchronous accept instead, yielding to the host every 100 ms.
   $pending=$listener.GetContextAsync()
   while(-not $pending.IsCompleted){
    Start-Sleep -Milliseconds 100
    if($interactiveConsole){
     try{
      if([Console]::KeyAvailable){
       $key=[Console]::ReadKey($true)
       if($key.Key -eq [ConsoleKey]::Q){
        $running=$false
        break
       }
      }
     }catch [System.InvalidOperationException]{
      $interactiveConsole=$false
     }catch [System.IO.IOException]{
      $interactiveConsole=$false
     }
    }
   }
   if(-not $running){break}
   # Preserve the existing request routing and media types.
   $ctx=$pending.GetAwaiter().GetResult()
   try{
    $rel=[uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
    if(!$rel -or $rel.EndsWith('/')){$rel+='index.html'}
    $full=[IO.Path]::GetFullPath((Join-Path $dir $rel))
    $base=[IO.Path]::GetFullPath($dir).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
    $comparison=if($IsWindows){[StringComparison]::OrdinalIgnoreCase}else{[StringComparison]::Ordinal}
    if(!$full.StartsWith($base,$comparison) -or !(Test-Path -LiteralPath $full -PathType Leaf)){
     $ctx.Response.StatusCode=404
    }else{
     $ext=[IO.Path]::GetExtension($full).ToLowerInvariant()
     $type=@{'.html'='text/html';'.css'='text/css';'.js'='text/javascript';'.svg'='image/svg+xml';
       '.png'='image/png';'.jpg'='image/jpeg';'.webp'='image/webp';'.xml'='application/xml'}
     $ctx.Response.ContentType=if($type.ContainsKey($ext)){$type[$ext]}else{'application/octet-stream'}
     $bytes=[IO.File]::ReadAllBytes($full)
     $ctx.Response.ContentLength64=$bytes.Length
     $ctx.Response.OutputStream.Write($bytes,0,$bytes.Length)
    }
   }finally{
    $ctx.Response.Close()
   }
  }
 }finally{
  if($started){
   $listener.Stop()
  }
  $listener.Close()
  if($started){Write-Host 'Zeta local server stopped. Port released.' -ForegroundColor Green}
 }
}


function RemoveSite([string]$name){
 $path=SiteDir $name
 [void](ConfigPath $name)
 if(!$Force){
  $confirmation=Read-Host "Type '$name' to delete the entire site"
  if($confirmation -cne $name){Write-Host 'Cancelled';return}
 }
 Remove-Item -LiteralPath $path -Recurse -Force
 Dashboard
 Write-Host "Deleted $name" -ForegroundColor Yellow
}
function FontSite([string]$name,[string]$choice=''){
 $dir=SiteDir $name
 [void](ConfigPath $name)
 $sources=@{
  'cascadia'=@{id='CascadiaCode';family='Cascadia Code';license='https://raw.githubusercontent.com/microsoft/cascadia-code/main/LICENSE';files=@(
   @('CascadiaCode.woff2','normal','200 700','https://raw.githubusercontent.com/sempitern0/Zeta/main/templates/common/assets/fonts/CascadiaCode/CascadiaCode.woff2'))}
  'jetbrains'=@{id='JetBrainsMono';family='JetBrains Mono';license='https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/OFL.txt';files=@(
   @('JetBrainsMono-Regular.woff2','normal','400','https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/webfonts/JetBrainsMono-Regular.woff2'),
   @('JetBrainsMono-Bold.woff2','normal','700','https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/webfonts/JetBrainsMono-Bold.woff2'))}
  'fira'=@{id='FiraCode';family='Fira Code';license='https://raw.githubusercontent.com/tonsky/FiraCode/master/LICENSE';files=@(
   @('FiraCode-Regular.woff2','normal','400','https://raw.githubusercontent.com/sempitern0/Zeta/main/templates/common/assets/fonts/FiraCode/FiraCode-Regular.woff2'))}
  'ibm-plex'=@{id='IBMPlexMono';family='IBM Plex Mono';license='https://raw.githubusercontent.com/IBM/plex/master/LICENSE.txt';files=@(
   @('IBMPlexMono-Regular.woff2','normal','400','https://raw.githubusercontent.com/IBM/plex/master/packages/plex-mono/fonts/complete/woff2/IBMPlexMono-Regular.woff2'))}
  'source-code'=@{id='SourceCodePro';family='Source Code Pro';license='https://raw.githubusercontent.com/adobe-fonts/source-code-pro/release/LICENSE.md';files=@(
   @('SourceCodePro-Regular.woff2','normal','400','https://raw.githubusercontent.com/adobe-fonts/source-code-pro/release/WOFF2/TTF/SourceCodePro-Regular.ttf.woff2'))}
 }
 if(!$choice){$choice=SelectItem 'Font' @('cascadia','jetbrains','fira','ibm-plex','source-code','remove') 'remove'}
 $assets=Join-Path $dir 'assets/fonts';$styles=Join-Path $dir 'styles'
 if($choice -eq 'remove'){
  if(Test-Path $assets){Remove-Item -LiteralPath $assets -Recurse -Force}
  $css=Join-Path $styles '90-font.css'
  if(Test-Path $css){Remove-Item -LiteralPath $css -Force}
  Write-Host 'Theme default fonts restored'
  Build $name;Dashboard;return
 }
 if(!$sources.ContainsKey($choice)){throw "Unknown font: $choice"}
 $spec=$sources[$choice]
 $cache=Join-Path $Root ".zeta-cache/fonts/$($spec.id)"
 $fontdir=Join-Path $assets $spec.id
 $stage=Join-Path $dir ('.zeta-font-ps-'+[guid]::NewGuid().ToString('N'))
 try{
  [void](New-Item -ItemType Directory -Path $cache,$stage -Force)
  $downloads=@($spec.files)
  $downloads+=,@('LICENSE.txt','','',$spec.license)
  foreach($entry in $downloads){
   $dest=Join-Path $cache $entry[0]
   if(!(Test-Path $dest)){Invoke-WebRequest -Uri $entry[3] -OutFile $dest -ErrorAction Stop}
   if((Get-Item $dest).Length -le 0){throw 'Empty font download'}
   Copy-Item -LiteralPath $dest -Destination $stage -Force
  }
  $cssParts=[Collections.Generic.List[string]]::new()
  foreach($entry in $spec.files){
   $cssParts.Add(('@font-face { font-family: "{0}"; src: url("../assets/fonts/{1}/{2}") format("woff2"); font-style: {3}; font-weight: {4}; font-display: swap; }' -f $spec.family,$spec.id,$entry[0],$entry[1],$entry[2]))
  }
  $cssParts.Add((':root { --font-mono: "{0}", ui-monospace, Consolas, monospace; --font-sans: "{0}", system-ui, sans-serif; }' -f $spec.family))
  [void](New-Item -ItemType Directory -Path $assets,$styles -Force)
  if(Test-Path $assets){Remove-Item -LiteralPath $assets -Recurse -Force}
  [void](New-Item -ItemType Directory -Path $assets -Force)
  Copy-Item -LiteralPath $stage -Destination $fontdir -Recurse -Force
  Save (Join-Path $styles '90-font.css') ($cssParts -join [Environment]::NewLine)
  Build $name;Dashboard
 } finally{
  if(Test-Path $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
 }
}

function ListPosts([string]$name){
 $c=Config $name
 foreach($file in @(Posts $name)){
  $p=PostInfo $file $c.author
  Write-Host ('{0,-12} {1,-40} {2}' -f $p.date,$p.title,$file.Name)
 }
}
