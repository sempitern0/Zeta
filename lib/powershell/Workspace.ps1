# Zeta PowerShell: site, post, fonts, preview, and maintenance.
# Same HTML, CSS, statuses and metadata as the Bash workspace dashboard.
function Dashboard {
 [void](New-Item -ItemType Directory -Path $Sites -Force)
 $template=Join-Path $Templates 'common/workspace/index.html'
 $stylesheet=Join-Path $Templates 'common/workspace/workspace.css'
 if(!(Test-Path -LiteralPath $template) -or !(Test-Path -LiteralPath $stylesheet)){
  throw 'Shared Zeta workspace templates are missing.'
 }
 $cards=[Collections.Generic.List[string]]::new()
 $siteCount=0;$builtCount=0;$postCount=0
 foreach($name in @(SiteNames)){
  $siteCount++
  $title=$name;$description='';$theme='unknown';$status='Draft';$author='—';$language='—';$output='—'
  $statusClass='';$cardClass='';$count=0;$url='';$errorHtml=''
  try{
   $c=Config $name
   $title=$c.title;$description=$c.description;$theme=$c.theme;$author=$c.author;$language=$c.language;$output=$c.output
   if(!(SafeDir $c.content)){throw "Invalid build.content_dir in $(ConfigPath $name)"}
   if(!(SafeDir $c.output)){throw "Invalid build.output_dir in $(ConfigPath $name)"}
   $count=@(Posts $name).Count
   if(Test-Path -LiteralPath (Join-Path (SiteDir $name) "$($c.output)/index.html") -PathType Leaf){
    $status='Ready';$statusClass='ready';$cardClass='built';$builtCount++
    $url='./'+(Escape $name)+'/'+(Escape $c.output.Replace('\','/'))+'/'
   }
  }catch{
   $status='Configuration issue';$statusClass='issue'
   $errorHtml='<p class="error">'+(Escape $_.Exception.Message)+'</p>'
  }
  $postCount+=$count
  $titleHtml=Escape $title
  $action='<span class="meta">Build this site to preview it.</span>'
  if($url){
   $titleHtml='<a href="'+$url+'">'+$titleHtml+'</a>'
   $action='<a class="preview" href="'+$url+'">Open preview →</a>'
  }elseif($errorHtml){$action=$errorHtml}
  $cards.Add('<article class="card '+$cardClass+'"><div class="card-header"><span class="eyebrow">SITE / '+(Escape $name)+'</span><span class="status '+$statusClass+'">'+(Escape $status)+'</span></div><h3>'+$titleHtml+'</h3><p class="desc">'+(Escape $description)+'</p><dl class="details"><div><dt>Theme</dt><dd>'+(Escape $theme)+'</dd></div><div><dt>Articles</dt><dd>'+$count+'</dd></div><div><dt>Author</dt><dd>'+(Escape $author)+'</dd></div><div><dt>Language</dt><dd>'+(Escape $language)+'</dd></div><div><dt>Output</dt><dd>'+(Escape $output)+'</dd></div></dl>'+$action+'</article>')
 }
 if($cards.Count -eq 0){$cards.Add('<p class="empty">No sites yet. Run zeta.sh create or zeta.ps1 create to begin.</p>')}
 $html=[IO.File]::ReadAllText($template)
 $html=$html.Replace('__ZETA_SITE_COUNT__',[string]$siteCount).Replace('__ZETA_BUILT_COUNT__',[string]$builtCount).Replace('__ZETA_POST_COUNT__',[string]$postCount).Replace('__ZETA_CARDS__',($cards.ToArray() -join [Environment]::NewLine))
 Save (Join-Path $Sites 'index.html') $html
 Copy-Item -LiteralPath $stylesheet -Destination (Join-Path $Sites 'workspace.css') -Force
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
 $author=Ask 'Author' ([Environment]::UserName)
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
 $blogReply=Ask 'Include a blog? (Y/n)' 'Y'
 $aboutReply=Ask 'Include an About page? (Y/n)' 'Y'
 $contactReply=Ask 'Include a Contact page? (y/N)' 'N'
 $withBlog=($blogReply -notmatch '^[Nn]')
 $withAbout=($aboutReply -notmatch '^[Nn]')
 $withContact=($contactReply -match '^[Yy]')
 $c=@{
  title=$title;description=$description;author=$author;language=$language;
  url=$url.TrimEnd('/');theme=$theme;highlight=$highlight;content='posts';output='public'
 }
 $created=$false
 try{
  [void](New-Item -ItemType Directory -Path (Join-Path $dir 'posts') -Force)
  $created=$true
  Save (Join-Path $dir 'config.yaml') ((ConfigText $c)+"  blog: $($withBlog.ToString().ToLowerInvariant())"+[Environment]::NewLine)
  foreach($page in @('index','about','contact')){
   if($page -eq 'about' -and -not $withAbout){continue}
   if($page -eq 'contact' -and -not $withContact){continue}
   $template=Join-Path $Templates "common/pages/$page.md"
   $body=[IO.File]::ReadAllText($template)
   $body=$body.Replace('__ZETA_SITE_TITLE__',(Quote $c.title)).Replace('__ZETA_SITE_DESCRIPTION__',(Quote $c.description))
   Save (Join-Path $dir "pages/$page.md") $body
  }
  if($withBlog){
   $today=Get-Date -Format yyyy-MM-dd
   $authorYaml=Quote $c.author
   $dateYaml=Quote $today
   foreach($example in @('markdown-showcase','code-showcase')){
    $source=Join-Path $Templates "common/examples/$example.md"
    if(!(Test-Path -LiteralPath $source)){throw "Missing shared example: $source"}
    $body=[IO.File]::ReadAllText($source)
    $body=$body.Replace('__ZETA_AUTHOR_YAML__',$authorYaml).Replace('__ZETA_DATE_YAML__',$dateYaml)
    Save (Join-Path (Join-Path $dir 'posts') "$today-zeta-$example.md") $body
   }
  }
 }catch{
  if($created -and (Test-Path -LiteralPath $dir)){Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue}
  throw
 }
 Write-Host "[OK] Site created: $dir ($($withBlog ? 2 : 0) sample posts, Markdown pages)" -ForegroundColor Green
 try{Dashboard}catch{Write-Warning "Workspace index update failed: $($_.Exception.Message)"}
 if(-not (Test-ZetaPandoc)){
  Write-Host 'Site sources are ready; Pandoc is needed for HTML generation.' -ForegroundColor Yellow
  if($IsWindows){[void](Install-ZetaPandoc)}
 }
 if(Test-ZetaPandoc){
  try{
   Build $slug
   Dashboard
   Write-Host "[OK] Generated static files in $(Join-Path $dir 'public')" -ForegroundColor Green
  }catch{
   Write-Warning "Site sources are saved, but the HTML build failed: $($_.Exception.Message)"
   Write-Host "Retry with: .\zeta.ps1 build $slug" -ForegroundColor Yellow
  }
 }
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
# Only modify the two theme keys: never serialize away custom YAML or build paths.
function Set-ZetaThemeFields([string]$yaml,[string]$theme,[string]$style) {
 $newline=if($yaml.Contains("`r`n")){"`r`n"}else{"`n"}
 $lines=$yaml -split '\r?\n'
 $result=[Collections.Generic.List[string]]::new()
 $inside=$false;$sectionFound=$false
 $nameFound=$false;$styleFound=$false
 foreach($line in $lines){
  if($line -match '^theme:\s*(?:#.*)?$'){
   if($sectionFound){throw 'Duplicate theme sections in site configuration'}
   $inside=$true;$sectionFound=$true
   $result.Add($line)
   continue
  }
  if($inside -and $line -match '^[^\s#]'){
   if(-not $nameFound){$result.Add('  name: '+(Quote $theme))}
   if(-not $styleFound){$result.Add('  pandoc_theme: '+(Quote $style))}
   $inside=$false
  }
  if($inside -and $line -match '^\s+name:\s*'){
   $result.Add('  name: '+(Quote $theme))
   $nameFound=$true
   continue
  }
  if($inside -and $line -match '^\s+pandoc_theme:\s*'){
   $result.Add('  pandoc_theme: '+(Quote $style))
   $styleFound=$true
   continue
  }
  $result.Add($line)
 }
 if($inside){
  if(-not $nameFound){$result.Add('  name: '+(Quote $theme))}
  if(-not $styleFound){$result.Add('  pandoc_theme: '+(Quote $style))}
 }
 if(-not $sectionFound){
  $result.Add('theme:')
  $result.Add('  name: '+(Quote $theme))
  $result.Add('  pandoc_theme: '+(Quote $style))
 }
 $result.ToArray() -join $newline
}
function ThemeSite([string]$name,[string]$theme,[string]$style=''){
 $c=Config $name
 $configPath=ConfigPath $name
 if(-not (SafeDir $c.content)){
  throw "Unsafe build.content_dir '$($c.content)' in $configPath. Use a relative directory, e.g. posts."
 }
 if(-not (SafeDir $c.output)){
  throw "Unsafe build.output_dir '$($c.output)' in $configPath. Use a relative directory, e.g. public."
 }
 if(!$theme){$theme=SelectItem 'Theme' @(Themes) $c.theme}
 if(@(Themes) -notcontains $theme){throw "Unknown theme '$theme'."}
 if(!$style){$style=SelectItem 'Pandoc highlight style' @(Get-ZetaHighlightStyles) $c.highlight}
 if(@(Get-ZetaHighlightStyles) -notcontains $style){throw "Unknown highlight style '$style'."}
 $originalBytes=[IO.File]::ReadAllBytes($configPath)
 try{
  $newYaml=Set-ZetaThemeFields ([IO.File]::ReadAllText($configPath)) $theme $style
  Save $configPath $newYaml
  $check=Config $name
  if($check.theme -ne $theme -or $check.highlight -ne $style){
   throw 'Theme selection was not saved correctly.'
  }
  Build $name
 }catch{
  [IO.File]::WriteAllBytes($configPath,$originalBytes)
  throw
 }
 Dashboard
 Write-Host "[OK] Theme changed to '$theme' with '$style' highlighting." -ForegroundColor Green
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
 $body=@(
  '---'
  ('title: {0}' -f (Quote $title))
  ('author: {0}' -f (Quote $c.author))
  ('date: {0}' -f (Quote $date))
  ('description: {0}' -f (Quote $desc))
  ('slug: {0}' -f (Quote $slug))
  'tags: []'
  '---'
  ''
  'Write your introduction here.'
  ''
  '## First section'
  ''
 )
 if($tags){
  $body=@($body[0..5])+@('tags:')+@(foreach($t in ($tags -split ',')){if($t.Trim()){'  - '+(Quote $t.Trim())}})+@($body[7..($body.Length-1)])
 }
 Save $file ($body -join [Environment]::NewLine)
 Write-Host "Created $file" -ForegroundColor Green
}
function ListSites{
 foreach($name in (SiteNames)){
  try{
   $c=Config $name
   if(-not (SafeDir $c.content)){throw "Invalid content_dir '$($c.content)' in $(ConfigPath $name)"}
   if(-not (SafeDir $c.output)){throw "Invalid output_dir '$($c.output)' in $(ConfigPath $name)"}
   $status=if(Test-Path (Join-Path (SiteDir $name) "$($c.output)/index.html")){'built'}else{'draft'}
   Write-Host ("{0,-24} {1,3} posts  {2,-15} {3}" -f $name,@(Posts $name).Count,$c.theme,$status)
  }catch{
   Write-Host ("{0,-24} CONFIG ERROR: {1}" -f $name,$_.Exception.Message) -ForegroundColor Yellow
  }
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


function ListPages([string]$name) {
 $dir=SiteDir $name
 [void](ConfigPath $name)
 $pageDir=Join-Path $dir 'pages'
 if(!(Test-Path -LiteralPath $pageDir -PathType Container)){
  Write-Host "No Markdown pages in $name";return
 }
 foreach($file in @(Get-ChildItem -LiteralPath $pageDir -Filter '*.md' -File | Sort-Object Name)){
  $title=Meta $file.FullName title
  Write-Host ("  {0,-20} {1}" -f $file.BaseName,$title)
 }
}
function NewPage([string]$name,[string]$title='', [string]$slug='') {
 $site=SiteDir $name
 [void](ConfigPath $name)
 if(!$title){$title=Read-Host 'Page title'}
 if([string]::IsNullOrWhiteSpace($title)){throw 'Page title cannot be empty'}
 if(!$slug){$slug=Slug $title}
 if($slug -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$' -or $slug -in @('posts','blog')){
  throw "Invalid page slug: $slug"
 }
 $target=Join-Path $site "pages/$slug.md"
 if(Test-Path -LiteralPath $target){throw "Page already exists: $target"}
 $desc="Information about $title"
 $text=@(
  '---'
  ('title: {0}' -f (Quote $title))
  ('description: {0}' -f (Quote $desc))
  'nav: true'
  'nav_order: 50'
  'draft: false'
  '---'
  ''
  ('## '+$title)
  ''
  'Write your page here in Markdown.'
 ) -join [Environment]::NewLine
 Save $target $text
 Write-Host "[OK] Markdown page created: $target" -ForegroundColor Green
 if(Test-ZetaPandoc){Build $name;Dashboard}
}
