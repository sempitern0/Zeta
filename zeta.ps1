#Requires -Version 7.0
param(
 [Parameter(Position=0)][string]$Command='',
 [Parameter(Position=1)][string]$Site='',
 [Parameter(Position=2)][string]$Value='',
 [switch]$Force,
 [int]$Port=8000
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=$PSScriptRoot
$Sites=Join-Path $Root 'sites'
$Templates=Join-Path $Root 'templates'
$Utf8=[Text.UTF8Encoding]::new($false)
function Save([string]$Path,[string]$Content) {
 $dir=Split-Path $Path -Parent
 if(!(Test-Path $dir)){[void](New-Item -ItemType Directory -Force -Path $dir)}
 [IO.File]::WriteAllText($Path,$Content,$Utf8)
}
function Escape([string]$s){[Net.WebUtility]::HtmlEncode($s)}
function Xml([string]$s){[Security.SecurityElement]::Escape($s)}
function Scalar([string]$s){
 $s=$s.Trim()
 if($s.Length -gt 1 -and $s.StartsWith('"') -and $s.EndsWith('"')){return $s.Substring(1,$s.Length-2).Replace('\"','"')}
 if($s.Length -gt 1 -and $s.StartsWith("'") -and $s.EndsWith("'")){return $s.Substring(1,$s.Length-2).Replace("''","'")}
 return $s
}
function Quote([string]$s){'"'+$s.Replace('\','\\').Replace('"','\"').Replace([char]10,' ')+'"'}
function Yaml([string]$path,[string]$section,[string]$key,[string]$fallback=''){
 if(!(Test-Path $path)){return $fallback}
 $active=$false
 foreach($line in [IO.File]::ReadAllLines($path)){
  if($line -match ('^'+[regex]::Escape($section)+':\s*$')){$active=$true;continue}
  if($line -match '^\S'){$active=$false}
  if($active -and $line -match ('^\s+'+[regex]::Escape($key)+':\s*(.*?)\s*$')){return Scalar $Matches[1]}
 }
 return $fallback
}
function Meta([string]$path,[string]$key){
 $lines=[IO.File]::ReadAllLines($path)
 if(!$lines.Length -or $lines[0].Trim() -ne '---'){return ''}
 if($lines.Length -lt 2){return ''}
 foreach($line in $lines[1..($lines.Length-1)]){
  if($line.Trim() -eq '---'){break}
  if($line -match ('^\s*'+[regex]::Escape($key)+':\s*(.*?)\s*$')){return Scalar $Matches[1]}
 }
 return ''
}
function Slug([string]$s){
 $s=$s.ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD)
 $s=-join ($s.ToCharArray() | Where-Object {[Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark'})
 return (($s -replace '[^a-z0-9]+','-').Trim('-'))
}
function SiteDir([string]$name){
 if($name -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_.-]*$' -or $name -in @('.','..')){throw "Invalid site: $name"}
 Join-Path $Sites $name
}
function ConfigPath([string]$name){
 $dir=SiteDir $name
 foreach($fn in @('config.yaml','config.yml')){$p=Join-Path $dir $fn;if(Test-Path $p){return $p}}
 throw "Unknown site: $name"
}
function Config([string]$name){
 $p=ConfigPath $name
 @{
 title=(Yaml $p site title $name);description=(Yaml $p site description 'Built with Zeta');
 author=(Yaml $p site author 'Author');language=(Yaml $p site language en);
 url=(Yaml $p site url 'https://example.com');theme=(Yaml $p theme name zen);
 highlight=(Yaml $p theme pandoc_theme zenburn);content=(Yaml $p build content_dir posts);
 output=(Yaml $p build output_dir public)
 }
}
function ConfigText([hashtable]$c){
 @(
 'site:','  title: '+(Quote $c.title),'  description: '+(Quote $c.description),
 '  author: '+(Quote $c.author),'  language: '+(Quote $c.language),'  url: '+(Quote $c.url),
 'theme:','  name: '+(Quote $c.theme),'  pandoc_theme: '+(Quote $c.highlight),
 'build:','  content_dir: '+(Quote $c.content),'  output_dir: '+(Quote $c.output)
 ) -join [Environment]::NewLine
}
function SafeDir([string]$s){
 $s -ne '' -and ![IO.Path]::IsPathRooted($s) -and $s -notmatch '(^|[/\\])\.\.([/\\]|$)|[:\r\n]'
}
function SafeLink([string]$s){
 if(!$s -or $s -match '[\s"<>]'){return $false}
 return ($s -match '^https?://[^/]+.*$' -or $s -match '^#[a-zA-Z0-9_-]+$' -or
  ($s -match '^[a-zA-Z0-9][a-zA-Z0-9_./?&=%#+~-]*$' -and $s -notmatch '(^|/)\.\.(/|$)'))
}
function Themes {
 @(Get-ChildItem $Templates -Directory | Where-Object {
  $_.Name -ne 'common' -and (Test-Path (Join-Path $_.FullName 'index.html')) -and
  (Test-Path (Join-Path $_.FullName 'article.html')) -and
  (Test-Path (Join-Path $_.FullName 'post_link.html'))
 } | ForEach-Object Name)
}
function SiteNames {
 if(!(Test-Path $Sites)){return @()}
 @(Get-ChildItem $Sites -Directory | Where-Object {
  Test-Path (Join-Path $_.FullName 'config.yaml')
 } | ForEach-Object Name | Sort-Object)
}
function Posts([string]$name){
 $c=Config $name
 if(!(SafeDir $c.content)){throw 'Unsafe content directory'}
 $path=Join-Path (SiteDir $name) $c.content
 if(!(Test-Path $path)){return @()}
 @(Get-ChildItem $path -File -Recurse -Filter '*.md' | Sort-Object FullName -Descending)
}
function PostInfo([IO.FileInfo]$file,[string]$defaultAuthor){
 $raw=[IO.Path]::GetFileNameWithoutExtension($file.Name)
 $slug=Meta $file.FullName slug
 if(!$slug){$slug=$raw -replace '^\d{4}(-\d{2}-\d{2})?-',''}
 $slug=Slug $slug
 $date=Meta $file.FullName date
 if(!$date -and $raw -match '^(\d{4}-\d{2}-\d{2})-'){$date=$Matches[1]}
 if(!$date){$date=(Get-Date -Format yyyy-MM-dd)}
 $year=Meta $file.FullName year
 if($year -notmatch '^\d{4}$'){$year=if($date.Length -ge 4){$date.Substring(0,4)}else{(Get-Date -Format yyyy)}}
 $title=Meta $file.FullName title
 if(!$title){$title=$slug}
 $author=Meta $file.FullName author
 if(!$author){$author=$defaultAuthor}
 $desc=Meta $file.FullName description
 if(!$desc){$desc=$title}
 $human=Meta $file.FullName human_date
 if(!$human){$human=$date}
 @{title=$title;slug=$slug;date=$date;year=$year;human=$human;author=$author;
   description=$desc;external_url=(Meta $file.FullName external_url)}
}
function Pandoc([string[]]$options){
 '' | & pandoc @options
 if($LASTEXITCODE -ne 0){throw 'Pandoc generation failed'}
}
function Layer([string]$from,[string]$to){
 if(!(Test-Path $from)){return}
 [void](New-Item -ItemType Directory -Path $to -Force)
 foreach($item in (Get-ChildItem $from -Force)){Copy-Item -LiteralPath $item.FullName -Destination $to -Recurse -Force}
}
function Styles([string]$theme,[string]$dir,[string]$prefix){
 $names=@('normalize.css','markdown.css')
 foreach($where in @((Join-Path $Templates 'common/styles'),(Join-Path $Templates "$theme/styles"),(Join-Path $dir 'styles'))){
  if(Test-Path $where){foreach($f in (Get-ChildItem $where -Filter '*.css' -File | Sort-Object Name)){
   if($where -eq (Join-Path $Templates 'common/styles') -and $f.Name -in @('normalize.css','markdown.css')){continue}
   $names+= $f.Name
  }}
 }
 $args=@()
 foreach($n in $names){$args+=@('-V',"css=$prefix"+"styles/$n")}
 return $args
}
function Build([string]$name){
 if(!(Get-Command pandoc -ErrorAction SilentlyContinue)){throw 'Pandoc required: https://pandoc.org/installing.html'}
 $dir=SiteDir $name;$c=Config $name
 if($c.url -notmatch '^https?://[^\s?#]+$'){throw 'Invalid production URL'}
 if(!(SafeDir $c.content) -or !(SafeDir $c.output)){throw 'Unsafe path'}
 $content=$c.content.Replace('\','/').Trim('/');$output=$c.output.Replace('\','/').Trim('/')
 if($content -eq $output -or $content.StartsWith("$output/") -or $output.StartsWith("$content/")){throw 'Build directory overlap'}
 if((Themes) -notcontains $c.theme){throw "Unknown theme: $($c.theme)"}
 $theme=Join-Path $Templates $c.theme
 $landing=Join-Path $dir 'landing.yaml';$extra=@{}
 foreach($k in @('eyebrow','primary_label','primary_url','secondary_label','secondary_url','hero_image','hero_alt')){
  $extra[$k]=Yaml $landing landing $k ''
 }
 foreach($k in @('primary_url','secondary_url')){if($extra[$k] -and !(SafeLink $extra[$k])){throw "Unsafe $k"}}
 if($extra.hero_image){
  if($extra.hero_image -notmatch '^assets/[A-Za-z0-9_./-]+$' -or $extra.hero_image -match '(^|/)\.\.(/|$)'){throw 'Unsafe hero path'}
  if(!(Test-Path (Join-Path $dir $extra.hero_image))){throw 'Missing hero image'}
 }
 $stage=Join-Path $dir ('.zeta-ps-'+[guid]::NewGuid().ToString('N'))
 $final=Join-Path $dir $c.output;$previous="$final.zeta-previous"
 $files=Posts $name
 try{
  [void](New-Item -ItemType Directory -Force -Path (Join-Path $stage 'styles'),(Join-Path $stage 'posts'))
  foreach($kind in @('styles','assets')){
   Layer (Join-Path $Templates "common/$kind") (Join-Path $stage $kind)
   Layer (Join-Path $theme $kind) (Join-Path $stage $kind)
   Layer (Join-Path $dir $kind) (Join-Path $stage $kind)
  }
  $body=''
  $landingMd=Join-Path $dir 'landing.md'
  if(Test-Path $landingMd){
   $body=(& pandoc $landingMd -f markdown -t html5 --wrap=none) -join [Environment]::NewLine
   if($LASTEXITCODE -ne 0){throw 'Invalid landing Markdown'}
  }
  $links=[Collections.Generic.List[string]]::new()
  $routes=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $hflag='--highlight-style'
  if(((& pandoc --help) -join [Environment]::NewLine).Contains('--syntax-highlighting')){$hflag='--syntax-highlighting'}
  foreach($file in $files){
   $p=PostInfo $file $c.author
   if($p.external_url -and !(SafeLink $p.external_url)){throw 'Unsafe external_url'}
   $rel="posts/$($p.year)/$($p.slug).html"
   if(!$routes.Add($rel)){throw "Duplicate route: $rel"}
   $target=Join-Path $stage $rel
   [void](New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force)
   $args=@($file.FullName,'-f','markdown','-t','html5','--standalone','--section-divs','--wrap=none',
      '--table-of-contents','--toc-depth=3','--preserve-tabs','--template='+ (Join-Path $theme 'article.html'),
      '-V','rel_root=../../','-V',"title=$(Escape $p.title)",'-V',"author=$(Escape $p.author)",
      '-V',"date=$(Escape $p.human)",'-V',"iso_date=$(Escape $p.date)",'-V',"year=$($p.year)",
      '-V',"slug=$($p.slug)",'-V',"description=$(Escape $p.description)",'-V',"site_title=$(Escape $c.title)",
      '-V',"site_author=$(Escape $c.author)",'-V',"site_lang=$(Escape $c.language)",
      "$hflag=$($c.highlight)")
   $filter=Join-Path $Templates 'common/filters/table-wrapper.lua'
   if(Test-Path $filter){$args+="--lua-filter=$filter"}
   $args+=@(Styles $c.theme $dir '../../')
   $args+=@('-o',$target)
   Pandoc $args
   $args=@('-f','markdown','--quiet','--template='+ (Join-Path $theme 'post_link.html'),
      '-V',"title=$(Escape $p.title)",'-V',"date=$(Escape $p.human)",'-V',"iso_date=$(Escape $p.date)",
      '-V',"path=$rel",'-V',"description=$(Escape $p.description)",'-V',"external_url=$(Escape $p.external_url)")
   $item=('' | & pandoc @args) -join [Environment]::NewLine
   if($LASTEXITCODE -ne 0){throw 'Post card rendering failed'}
   $links.Add($item)
  }
  $vars=@{site_lang=(Escape $c.language);site_title=(Escape $c.title);site_desc=(Escape $c.description);
    site_author=(Escape $c.author);posts_list=($links -join [Environment]::NewLine);landing_content=$body}
  foreach($k in $extra.Keys){$vars[$k]=Escape $extra[$k]}
  foreach($tpl in (Get-ChildItem $theme -Filter '*.html' -File)){
   if($tpl.Name -in @('article.html','post_link.html')){continue}
   $args=@('-f','markdown','-t','html5','--quiet',"--template=$($tpl.FullName)")
   foreach($k in $vars.Keys){$args+=@('-V',('{0}={1}' -f $k,$vars[$k]))}
   $args+=@(Styles $c.theme $dir '')
   $args+=@('-o',(Join-Path $stage $tpl.Name))
   Pandoc $args
  }
  if(!(Test-Path (Join-Path $stage 'index.html'))){throw 'Theme did not generate index'}
  $base=$c.url.TrimEnd('/')
  $robot=[IO.File]::ReadAllText((Join-Path $Templates 'robots.txt')).Replace('{{BASE_URL}}',$base)
  Save (Join-Path $stage 'robots.txt') $robot
  $xsl=Join-Path $theme 'sitemap.xsl'
  if(!(Test-Path $xsl)){$xsl=Join-Path $Templates 'common/sitemap.xsl'}
  Copy-Item $xsl (Join-Path $stage 'sitemap.xsl') -Force
  $today=Get-Date -Format yyyy-MM-dd
  $locs=@("$base/","$base/posts.html")
  foreach($file in $files){$p=PostInfo $file $c.author;$locs+="$base/posts/$($p.year)/$($p.slug).html"}
  $rows=foreach($loc in $locs){"<url><loc>$(Xml $loc)</loc><lastmod>$today</lastmod></url>"}
  $xml='<?xml version="1.0" encoding="UTF-8"?>'+[Environment]::NewLine+
    '<?xml-stylesheet type="text/xsl" href="sitemap.xsl"?>'+[Environment]::NewLine+
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+
    ($rows -join [Environment]::NewLine)+'</urlset>'
  Save (Join-Path $stage 'sitemap.xml') $xml
  if(Test-Path $previous){Remove-Item $previous -Recurse -Force}
  if(Test-Path $final){Move-Item $final $previous}
  try{Move-Item $stage $final}catch{if(Test-Path $previous){Move-Item $previous $final};throw}
  if(Test-Path $previous){Remove-Item $previous -Recurse -Force}
  Write-Host "[OK] $name : $($files.Count) articles" -ForegroundColor Green
 } finally {if(Test-Path $stage){Remove-Item $stage -Recurse -Force}}
}
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
 for($i=0;$i -lt $items.Count;$i++){Write-Host ("[{0}] {1}" -f ($i+1),$items[$i])}
 $answer=Read-Host $title
 if(!$answer){return $fallback}
 $n=0
 if(![int]::TryParse($answer,[ref]$n) -or $n -lt 1 -or $n -gt $items.Count){throw 'Invalid selection'}
 return $items[$n-1]
}
function Ask([string]$title,[string]$fallback=''){
 $v=Read-Host ("$title [$fallback]")
 if(!$v){return $fallback};return $v
}
function NewSite{
 $title=Ask 'Site title' 'My New Blog'
 $slug=Ask 'Site slug' (Slug $title)
 $dir=SiteDir $slug;if(Test-Path $dir){throw 'Site already exists'}
 $theme=SelectItem 'Theme' (Themes) 'zen'
 $c=@{title=$title;description=(Ask 'Description' 'Built with Zeta');
 author=(Ask 'Author' [Environment]::UserName);language='en';url=(Ask 'Production URL' 'https://example.com');
 theme=$theme;highlight='zenburn';content='posts';output='public'}
 [void](New-Item -ItemType Directory -Path (Join-Path $dir 'posts') -Force)
 Save (Join-Path $dir 'config.yaml') (ConfigText $c)
 Dashboard
 Write-Host "Created $dir" -ForegroundColor Green
}
function EditSite([string]$name){
 $c=Config $name
 foreach($k in @('title','description','author','language','url')){$c[$k]=Ask $k $c[$k]}
 Save (ConfigPath $name) (ConfigText $c);Dashboard
}
function ThemeSite([string]$name,[string]$theme){
 $c=Config $name
 if(!$theme){$theme=SelectItem 'Theme' (Themes) $c.theme}
 if((Themes) -notcontains $theme){throw 'Unknown theme'}
 $c.theme=$theme
 Save (ConfigPath $name) (ConfigText $c)
 Build $name;Dashboard
}
function NewPost([string]$name){
 $c=Config $name
 $title=Ask 'Title';if(!$title){throw 'Title required'}
 $slug=Slug (Ask 'Slug' (Slug $title))
 $date=Get-Date -Format yyyy-MM-dd
 $file=Join-Path (Join-Path (SiteDir $name) $c.content) "$date-$slug.md"
 if((Test-Path $file) -and !$Force){throw 'Article exists'}
 $desc=Ask 'Description' $title
 $body=@('---','title: '+(Quote $title),'author: '+(Quote $c.author),
 'date: '+(Quote $date),'description: '+(Quote $desc),'slug: '+(Quote $slug),
 'tags: []','---','','Write your introduction here.','','## First section','')
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
 if(!(SafeDir $c.output) -or !(SafeDir $c.content) -or $c.output -eq $c.content){throw 'Unsafe output directory'}
 $p=Join-Path (SiteDir $name) $c.output
 if(Test-Path $p){Remove-Item $p -Recurse -Force}
}
function Doctor([string]$name){
 $c=Config $name;$errors=@()
 if((Themes) -notcontains $c.theme){$errors+='Invalid theme'}
 if(!(Get-Command pandoc -ErrorAction SilentlyContinue)){$errors+='Pandoc missing'}
 if(!(Test-Path (Join-Path (SiteDir $name) "$($c.output)/index.html"))){$errors+='Not built'}
 if($errors.Count){throw ($errors -join '; ')}
 Write-Host "[OK] $name" -ForegroundColor Green
}
function Preview([string]$name,[int]$serverPort){
 Build $name
 $c=Config $name
 $dir=Join-Path (SiteDir $name) $c.output
 Serve $dir $serverPort
}
function Serve([string]$dir,[int]$serverPort){
 $listener=[Net.HttpListener]::new()
 $listener.Prefixes.Add("http://localhost:$serverPort/")
 try {
  $listener.Start();Write-Host "http://localhost:$serverPort/ (Ctrl+C to stop)"
  while($listener.IsListening){
   $ctx=$listener.GetContext()
   try {
    $rel=[uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
    if(!$rel -or $rel.EndsWith('/')){$rel+='index.html'}
    $full=[IO.Path]::GetFullPath((Join-Path $dir $rel))
    $base=[IO.Path]::GetFullPath($dir).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
    $comparison=if($IsWindows){[StringComparison]::OrdinalIgnoreCase}else{[StringComparison]::Ordinal}
    if(!$full.StartsWith($base,$comparison) -or !(Test-Path $full -PathType Leaf)){$ctx.Response.StatusCode=404}
    else{
     $ext=[IO.Path]::GetExtension($full).ToLowerInvariant()
     $type=@{'.html'='text/html';'.css'='text/css';'.js'='text/javascript';'.svg'='image/svg+xml';
       '.png'='image/png';'.jpg'='image/jpeg';'.webp'='image/webp';'.xml'='application/xml'}
     $ctx.Response.ContentType=if($type.ContainsKey($ext)){$type[$ext]}else{'application/octet-stream'}
     $bytes=[IO.File]::ReadAllBytes($full);$ctx.Response.ContentLength64=$bytes.Length
     $ctx.Response.OutputStream.Write($bytes,0,$bytes.Length)
    }
   } finally{$ctx.Response.Close()}
  }
 } finally{$listener.Close()}
}
function Help{
 Write-Host @'
ZETA — Markdown-first publishing
  ./zeta.ps1                    Interactive assistant
  ./zeta.ps1 sites              List sites
  ./zeta.ps1 create             Create a site
  ./zeta.ps1 edit SITE          Edit metadata
  ./zeta.ps1 theme SITE THEME   Change theme and rebuild
  ./zeta.ps1 posts SITE         List Markdown posts
  ./zeta.ps1 new-post SITE      Add an article
  ./zeta.ps1 build SITE         Build a site
  ./zeta.ps1 build-all          Build all sites
  ./zeta.ps1 doctor SITE        Inspect deployment readiness
  ./zeta.ps1 preview SITE       Preview on localhost
  ./zeta.ps1 serve              Serve workspace
  ./zeta.ps1 clean SITE         Clean public/
  ./zeta.ps1 dashboard          Generate workspace index
Requires PowerShell 7+ and Pandoc for builds. No Bash/WSL/Node.
'@
}
function Menu{
 while($true){
  Clear-Host
  Write-Host '  ZETA / create · write · publish' -ForegroundColor Cyan
  Write-Host ('-'*56)
  Write-Host ("  Workspace   $((SiteNames).Count) sites")
  if(Get-Command pandoc -ErrorAction SilentlyContinue){Write-Host '  Renderer    ready' -ForegroundColor Green}
  else{Write-Host '  Renderer    Pandoc missing' -ForegroundColor Yellow}
  Write-Host ('-'*56)
  ListSites
  Write-Host '[1] List sites       [2] Create      [3] New post'
  Write-Host '[4] Build one        [5] Build all   [6] Preview'
  Write-Host '[7] Theme            [8] Doctor      [?] Help   [0] Exit'
  $a=Read-Host 'zeta >'
  try{
   switch($a){
    '1'{ListSites}
    '2'{NewSite}
    '3'{NewPost (SelectItem 'Site' (SiteNames))}
    '4'{Build (SelectItem 'Site' (SiteNames));Dashboard}
    '5'{foreach($n in (SiteNames)){Build $n};Dashboard}
    '6'{Preview (SelectItem 'Site' (SiteNames)) $Port}
    '7'{ThemeSite (SelectItem 'Site' (SiteNames)) ''}
    '8'{Doctor (SelectItem 'Site' (SiteNames))}
    '?'{Help}
    '0'{return}
    default{Write-Host 'Invalid selection' -ForegroundColor Yellow}
   }
  }catch{Write-Host "[ERROR] $_" -ForegroundColor Red}
  [void](Read-Host 'Enter to continue')
 }
}
try {
 switch($Command.ToLowerInvariant()){
  ''{Menu}
  'help'{Help}
  'sites'{ListSites}
  'list'{ListSites}
  'create'{NewSite}
  'edit'{EditSite $Site}
  'theme'{ThemeSite $Site $Value}
  'posts'{foreach($f in (Posts $Site)){Write-Host $f.Name}}
  'new-post'{NewPost $Site}
  'build'{Build $Site;Dashboard}
  'update'{Build $Site;Dashboard}
  'build-all'{foreach($n in (SiteNames)){Build $n};Dashboard}
  'doctor'{Doctor $Site}
  'preview'{Preview $Site $Port}
  'serve'{foreach($n in (SiteNames)){Build $n};Dashboard;Serve $Sites $Port}
  'dashboard'{Dashboard}
  'clean'{Clean $Site}
  default{throw "Unknown command: $Command"}
 }
}catch{Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red;exit 1}
