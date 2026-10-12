# Zeta PowerShell: Markdown, YAML, generation, and static output.
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
function Tags([string]$path){
 $lines=[IO.File]::ReadAllLines($path)
 if($lines.Length -lt 2 -or $lines[0].Trim() -ne '---'){return @()}
 $result=@();$list=$false
 for($i=1;$i -lt $lines.Length;$i++){
  $line=$lines[$i]
  if($line.Trim() -eq '---'){break}
  if($line -match '^\s*tags:\s*(.*)$'){
   $raw=$Matches[1].Trim()
   if($raw){
    $raw=$raw.Trim('[',']')
    foreach($part in ($raw -split ',')){$v=Scalar $part;if($v){$result+=$v}}
    break
   }
   $list=$true;continue
  }
  if($list -and $line -match '^\s+-\s+(.*)$'){$v=Scalar $Matches[1];if($v){$result+=$v}}
  elseif($list -and $line -match '^\s+\w+:'){break}
 }
 return $result
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
 $s -ne '' -and $s -notin @('.','..') -and ![IO.Path]::IsPathRooted($s) -and $s -notmatch '(^|[/\\])\.\.([/\\]|$)|[:\r\n]'
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
   description=$desc;external_url=(Meta $file.FullName external_url);tags=@(Tags $file.FullName)}
}
function Invoke-ZetaPandoc([string[]]$options){
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
   foreach($tag in $p.tags){$args+=@('-V',('tags='+(Escape $tag)))}
   $args+=@('-o',$target)
   Invoke-ZetaPandoc $args
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
   Invoke-ZetaPandoc $args
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
