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
 if($s.Length -gt 1 -and $s.StartsWith('"') -and $s.EndsWith('"')){return $s.Substring(1,$s.Length-2).Replace('\"','"').Replace('\\','\')}
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
 if($lines.Length -lt 2 -or $lines[0].Trim() -ne '---'){return ''}
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
# Emit one complete YAML key/value per line. In PowerShell comma expressions
# combined with + can otherwise yield separate array items for keys and values.
function ConfigText([hashtable]$c){
 $lines=@(
  'site:'
  ('  title: {0}' -f (Quote $c.title))
  ('  description: {0}' -f (Quote $c.description))
  ('  author: {0}' -f (Quote $c.author))
  ('  language: {0}' -f (Quote $c.language))
  ('  url: {0}' -f (Quote $c.url))
  'theme:'
  ('  name: {0}' -f (Quote $c.theme))
  ('  pandoc_theme: {0}' -f (Quote $c.highlight))
  'build:'
  ('  content_dir: {0}' -f (Quote $c.content))
  ('  output_dir: {0}' -f (Quote $c.output))
 )
 return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
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
  (Test-Path (Join-Path $_.FullName 'config.yaml')) -or (Test-Path (Join-Path $_.FullName 'config.yml'))
 } | ForEach-Object Name | Sort-Object)
}
function Posts([string]$name){
 $c=Config $name
 if(!(SafeDir $c.content)){throw "Invalid build.content_dir '$($c.content)' in $(ConfigPath $name). Use a relative path such as posts; check the YAML file."}
 $path=Join-Path (SiteDir $name) $c.content
 if(!(Test-Path $path)){return @()}
 @(Get-ChildItem $path -File -Recurse -Filter '*.md' | Sort-Object FullName -Descending)
}
function PostInfo([IO.FileInfo]$file,[string]$defaultAuthor){
 $raw=[IO.Path]::GetFileNameWithoutExtension($file.Name)
 $slug=Meta $file.FullName slug
 if(!$slug){$slug=$raw -replace '^\d{4}(-\d{2}-\d{2})?-',''}
 $slug=Slug $slug
 if(!$slug){$slug='post'}
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
# Resolve a theme template to a real, absolute file before invoking Pandoc.
# Pandoc otherwise searches its data directory and reports misleading ".html5" paths.
function Get-ZetaTemplate([string]$themeDirectory,[string]$fileName){
 if([string]::IsNullOrWhiteSpace($themeDirectory) -or [string]::IsNullOrWhiteSpace($fileName)){
  throw 'Theme directory and template name must both be provided.'
 }
 $fullPath=[IO.Path]::GetFullPath((Join-Path -Path $themeDirectory -ChildPath $fileName))
 if(-not (Test-Path -LiteralPath $fullPath -PathType Leaf)){
  throw "Theme template missing: '$fullPath'. Verify the selected theme in config.yaml and templates/."
 }
 return $fullPath
}
function Invoke-ZetaPandoc([string[]]$options){
 '' | & pandoc @options
 if($LASTEXITCODE -ne 0){
  $outputTarget='generated HTML'
  for($i=0;$i -lt $options.Count-1;$i++){
   if($options[$i] -eq '-o'){$outputTarget=$options[$i+1];break}
  }
  throw "Pandoc failed while generating '$outputTarget' (exit code $LASTEXITCODE)."
 }
}
function Layer([string]$from,[string]$to){
 if(!(Test-Path $from)){return}
 [void](New-Item -ItemType Directory -Path $to -Force)
 foreach($item in (Get-ChildItem $from -Force)){Copy-Item -LiteralPath $item.FullName -Destination $to -Recurse -Force}
}
function Styles([string]$theme,[string]$dir,[string]$prefix){
 $names=@('normalize.css')
 foreach($where in @((Join-Path $Templates 'common/styles'),(Join-Path $Templates "$theme/styles"),(Join-Path $dir 'styles'))){
  if(Test-Path $where){foreach($f in (Get-ChildItem $where -Filter '*.css' -File | Sort-Object Name)){
   if($where -eq (Join-Path $Templates 'common/styles') -and $f.Name -eq 'normalize.css'){continue}
   $names+= $f.Name
  }}
 }
 $styleOptions=@()
 foreach($n in $names){$styleOptions+=@('-V',("css=${prefix}styles/$n"))}
 return $styleOptions
}
function Build([string]$name){
 Assert-ZetaPandoc
 $dir=SiteDir $name;$c=Config $name
 if($c.language -notmatch '^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*
 if($c.url -notmatch '^https?://[^\s?#]+$'){throw 'Invalid production URL'}
 if(-not (SafeDir $c.content)){throw "Unsafe build.content_dir '$($c.content)' in $(ConfigPath $name): expected relative path such as posts."}
 if(-not (SafeDir $c.output)){throw "Unsafe build.output_dir '$($c.output)' in $(ConfigPath $name): expected relative path such as public."}
 $content=$c.content.Replace('\','/').Trim('/');$output=$c.output.Replace('\','/').Trim('/')
 if($content -eq $output -or $content.StartsWith("$output/") -or $output.StartsWith("$content/")){throw 'Build directory overlap'}
 if((Themes) -notcontains $c.theme){throw "Unknown theme: $($c.theme)"}
 $theme=Join-Path -Path $Templates -ChildPath $c.theme
 $articleTemplate=Get-ZetaTemplate $theme 'article.html'
 $cardTemplate=Get-ZetaTemplate $theme 'post_link.html'
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
 $files=@(Posts $name)
 if(Test-Path -LiteralPath (Join-Path $dir 'pages') -PathType Container){
  Ensure-ZetaPageHome $name
 }
 if((Test-Path -LiteralPath (Join-Path $dir 'pages/index.md') -PathType Leaf) -and
    ((Yaml (ConfigPath $name) build blog 'true') -eq 'false')){$files=@()}
 $hasMarkdownPages=Test-Path -LiteralPath (Join-Path $dir 'pages/index.md') -PathType Leaf
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
   $pandocOptions=@($file.FullName,'-f','markdown+autolink_bare_uris','-t','html5','--standalone','--section-divs','--wrap=none',
      '--table-of-contents','--toc-depth=3','--preserve-tabs','--template',$articleTemplate,
      '-V','rel_root=../../','-V',"title=$(Escape $p.title)",'-V',"author=$(Escape $p.author)",
      '-V',"date=$(Escape $p.human)",'-V',"iso_date=$(Escape $p.date)",'-V',"year=$($p.year)",
      '-V',"slug=$($p.slug)",'-V',"description=$(Escape $p.description)",'-V',"site_title=$(Escape $c.title)",
      '-V',"site_author=$(Escape $c.author)",'-V',"site_lang=$(Escape $c.language)",
      "$hflag=$($c.highlight)")
   $filter=Join-Path $Templates 'common/filters/table-wrapper.lua'
   if(Test-Path $filter){$pandocOptions+="--lua-filter=$filter"}
   if($hasMarkdownPages){$pandocOptions+=@('-V',('page_navigation='+(Get-ZetaPageNavigation $name '../../' 'blog' $true)))}
   $pandocOptions+=@(Styles $c.theme $dir '../../')
   foreach($tag in $p.tags){$pandocOptions+=@('-V',('tags='+(Escape $tag)))}
   $pandocOptions+=@('-o',$target)
   Invoke-ZetaPandoc $pandocOptions
   $pandocOptions=@('-f','markdown','-t','html5','--standalone','--quiet','--template',$cardTemplate,
      '-V',"title=$(Escape $p.title)",'-V',"date=$(Escape $p.human)",'-V',"iso_date=$(Escape $p.date)",
      '-V',"path=$rel",'-V',"description=$(Escape $p.description)",'-V',"external_url=$(Escape $p.external_url)")
   $item=('' | & pandoc @pandocOptions) -join [Environment]::NewLine
   if($LASTEXITCODE -ne 0){throw "Post card rendering failed for '$($file.Name)' (exit code $LASTEXITCODE)."}
   $links.Add($item)
  }
  $vars=@{site_lang=(Escape $c.language);site_title=(Escape $c.title);site_desc=(Escape $c.description);
    site_author=(Escape $c.author);landing_content=$body}
  # Avoid Windows' 32767-character process argument limit for long archives.
  # Pandoc reads the (possibly large) list of post cards from a local YAML file.
  $postsMeta=Join-Path $stage '.zeta-posts-list.yaml'
  $cardMarkup=$links.ToArray() -join [Environment]::NewLine
  $yamlLines=[Collections.Generic.List[string]]::new()
  if($cardMarkup){
   $yamlLines.Add('posts_list: |')
   foreach($line in ($cardMarkup -split "\r?\n")){$yamlLines.Add('  '+$line)}
  }else{$yamlLines.Add("posts_list: ''")}
  Save $postsMeta ($yamlLines.ToArray() -join [Environment]::NewLine)
  foreach($k in $extra.Keys){$vars[$k]=Escape $extra[$k]}
  $pagesDir=Join-Path $dir 'pages'
  $pagesMode=Test-Path -LiteralPath (Join-Path $pagesDir 'index.md') -PathType Leaf
  $blogEnabled=(-not $pagesMode) -or ((Yaml (ConfigPath $name) build blog 'true') -ne 'false')
  foreach($tpl in (Get-ChildItem $theme -Filter '*.html' -File)){
   if($pagesMode -and ($tpl.Name -eq 'index.html' -or (-not $blogEnabled -and $tpl.Name -eq 'posts.html'))){continue}
   if($tpl.Name -in @('article.html','post_link.html')){continue}
   $pageTemplate=Get-ZetaTemplate $theme $tpl.Name
   $pandocOptions=@('-f','markdown','-t','html5','--standalone','--quiet','--template',$pageTemplate,'--metadata-file',$postsMeta)
   foreach($k in $vars.Keys){$pandocOptions+=@('-V',('{0}={1}' -f $k,$vars[$k]))}
   if($pagesMode -and $tpl.Name -eq 'posts.html'){
    $pandocOptions+=@('-V',('page_navigation='+(Get-ZetaPageNavigation $name './' 'blog' $blogEnabled)))
   }
   $pandocOptions+=@(Styles $c.theme $dir '')
   $pandocOptions+=@('-o',(Join-Path $stage $tpl.Name))
   Invoke-ZetaPandoc $pandocOptions
  }
  Remove-Item -LiteralPath $postsMeta -Force
  if($pagesMode){Render-ZetaPages $name $stage $c $blogEnabled}
  if(!(Test-Path (Join-Path $stage 'index.html'))){throw 'Theme did not generate index'}
  $base=$c.url.TrimEnd('/')
  $robot=[IO.File]::ReadAllText((Join-Path $Templates 'robots.txt')).Replace('{{BASE_URL}}',$base)
  Save (Join-Path $stage 'robots.txt') $robot
  $xsl=Join-Path $theme 'sitemap.xsl'
  if(!(Test-Path $xsl)){$xsl=Join-Path $Templates 'common/sitemap.xsl'}
  Copy-Item $xsl (Join-Path $stage 'sitemap.xsl') -Force
  $today=Get-Date -Format yyyy-MM-dd
  $locs=@("$base/")
  if($blogEnabled){$locs+="$base/posts.html"}
  if($blogEnabled){foreach($file in $files){$p=PostInfo $file $c.author;$locs+="$base/posts/$($p.year)/$($p.slug).html"}}
  if($pagesMode){
   foreach($file in @(Get-ChildItem $pagesDir -Filter '*.md' -File)){
    if($file.BaseName -eq 'index' -or (Meta $file.FullName draft) -eq 'true'){continue}
    $locs+="$base/$($file.BaseName)/"
   }
  }
  $rows=foreach($loc in $locs){"<url><loc>$(Xml $loc)</loc><lastmod>$today</lastmod></url>"}
  $xml='<?xml version="1.0" encoding="UTF-8"?>'+[Environment]::NewLine+
    '<?xml-stylesheet type="text/xsl" href="sitemap.xsl"?>'+[Environment]::NewLine+
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+
    ($rows -join [Environment]::NewLine)+'</urlset>'
  Save (Join-Path $stage 'sitemap.xml') $xml
  # Generate the taxonomy archives before shared SEO.
  if($blogEnabled){
   $taxPath=Join-Path $stage '.zeta-taxonomy.tsv'
   $taxonomyRows=[Collections.Generic.List[string]]::new()
   foreach($file in $files){
    $post=PostInfo $file $c.author
    $route="posts/$($post.year)/$($post.slug).html"
    $category=Meta $file.FullName category
    if($category){
     $term=Slug $category
     if(!$term){throw "Invalid category: $($file.FullName)"}
     $taxonomyRows.Add((@($route,'category',$term,$category) -join [char]9))
    }
    foreach($tag in @($post.tags)){
     if(!$tag){continue}
     $term=Slug $tag
     if(!$term){throw "Invalid tag: $($file.FullName)"}
     $taxonomyRows.Add((@($route,'tag',$term,$tag) -join [char]9))
    }
   }
   if($taxonomyRows.Count -gt 0){
    Save $taxPath ($taxonomyRows -join [Environment]::NewLine)
    $filter=Join-Path $Templates 'common/filters/taxonomies.lua'
    if(!(Test-Path -LiteralPath $filter)){throw "Missing taxonomy filter: $filter"}
    $temporary=[IO.Path]::GetTempFileName()
    try{
     $pandocArgs=@('-f','markdown','-t','plain',("--lua-filter=$filter"),'-M',("zeta_taxonomy_output=$stage"),'-M',("zeta_taxonomy_url=$($c.url.TrimEnd('/'))"),'-M',("zeta_taxonomy_title=$($c.title)"),'-M',("zeta_taxonomy_language=$($c.language)"),'-o',$temporary)
     $null=@('' | & pandoc @pandocArgs)
     if($LASTEXITCODE -ne 0){throw 'Taxonomy generation failed'}
    }finally{Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue}
    Remove-Item -LiteralPath $taxPath -Force
   }
  }
  # Apply shared SEO before replacing public/.
  $seoFilter=Join-Path $Templates 'common/filters/seo-publish.lua'
  if(!(Test-Path -LiteralPath $seoFilter -PathType Leaf)){throw "Missing SEO filter: $seoFilter"}
  $seoTmp=[IO.Path]::GetTempFileName()
  try{
   $seoArgs=@('-f','markdown','-t','plain',("--lua-filter=$seoFilter"),'-M',("zeta_seo_output=$stage"),'-M',("zeta_seo_url=$($c.url.TrimEnd('/'))"),'-M',("zeta_seo_title=$($c.title)"),'-M',("zeta_seo_description=$($c.description)"),'-M',("zeta_seo_image=$(Yaml (ConfigPath $name) site image '')"),'-o',$seoTmp)
   $null=@('' | & pandoc @seoArgs)
   if($LASTEXITCODE -ne 0){throw 'Shared SEO generation failed; existing public/ was preserved'}
  }finally{Remove-Item -LiteralPath $seoTmp -Force -ErrorAction SilentlyContinue}
  # Only explicit editorial updated dates are used for sitemap lastmod.
  $updates=Join-Path $stage '.zeta-updates.tsv'
  $dateRows=[Collections.Generic.List[string]]::new()
  if($pagesMode){
   foreach($file in @(Get-ChildItem $pagesDir -Filter '*.md' -File)){
    if((Meta $file.FullName draft) -eq 'true'){continue}
    $updated=Meta $file.FullName updated
    if(!$updated){continue}
    if($updated -notmatch '^\d{4}-\d{2}-\d{2}$'){throw "Invalid updated date in $($file.FullName)"}
    $route=if($file.BaseName -eq 'index'){'index.html'}else{$file.BaseName+'/index.html'}
    $dateRows.Add(($route,$updated -join [char]9))
   }
  }
  if($blogEnabled){
   foreach($file in $files){
    $updated=Meta $file.FullName updated
    if(!$updated){continue}
    if($updated -notmatch '^\d{4}-\d{2}-\d{2}$'){throw "Invalid updated date in $($file.FullName)"}
    $post=PostInfo $file $c.author
    $dateRows.Add((("posts/{0}/{1}.html" -f $post.year,$post.slug),$updated -join [char]9))
   }
  }
  Save $updates ($dateRows -join [Environment]::NewLine)
  $extrasFilter=Join-Path $Templates 'common/filters/publish-extras.lua'
  if(!(Test-Path -LiteralPath $extrasFilter -PathType Leaf)){throw "Missing publishing filter: $extrasFilter"}
  $extrasTemp=[IO.Path]::GetTempFileName()
  try{
   $extrasArgs=@('-f','markdown','-t','plain',("--lua-filter=$extrasFilter"),'-M',("zeta_extra_output=$stage"),'-M',("zeta_extra_url=$($c.url.TrimEnd('/'))"),'-M',("zeta_extra_title=$($c.title)"),'-M',("zeta_extra_description=$($c.description)"),'-M',("zeta_extra_author=$($c.author)"),'-M',("zeta_extra_language=$($c.language)"),'-M',("zeta_extra_blog=$($blogEnabled.ToString().ToLowerInvariant())"),'-o',$extrasTemp)
   $null=@('' | & pandoc @extrasArgs)
   if($LASTEXITCODE -ne 0){throw 'RSS/Atom, structured data or sitemap generation failed'}
  }finally{Remove-Item -LiteralPath $extrasTemp -Force -ErrorAction SilentlyContinue}
  Remove-Item -LiteralPath $updates -Force

  if(Test-Path $previous){Remove-Item $previous -Recurse -Force}
  if(Test-Path $final){Move-Item $final $previous}
  try{Move-Item $stage $final}catch{if(Test-Path $previous){Move-Item $previous $final};throw}
  if(Test-Path $previous){Remove-Item $previous -Recurse -Force}
  Write-Host "[OK] $name : $($files.Count) articles" -ForegroundColor Green
 } finally {if(Test-Path $stage){Remove-Item $stage -Recurse -Force}}
}


# Shared Markdown pages are compiled inside Build's staging directory.
function Get-ZetaPageNavigation([string]$name,[string]$prefix,[string]$active,[bool]$blogEnabled) {
 $pages=Join-Path (SiteDir $name) 'pages'
 $entries=[Collections.Generic.List[object]]::new()
 foreach($file in @(Get-ChildItem -LiteralPath $pages -Filter '*.md' -File)) {
  $slug=$file.BaseName
  if($slug -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$' -or $slug -in @('posts','blog')){throw "Invalid page: $slug"}
  if((Meta $file.FullName draft) -eq 'true' -or (Meta $file.FullName nav) -eq 'false'){continue}
  $title=Meta $file.FullName menu_title
  if(!$title){$title=Meta $file.FullName title}
  if(!$title){$title=$slug}
  $order=50;$raw=Meta $file.FullName nav_order
  if($raw -match '^\d{1,3}$'){$order=[int]$raw}
  if($slug -eq 'index'){$order=0}
  $entries.Add([pscustomobject]@{Slug=$slug;Title=$title;Order=$order})
 }
 $links=[Collections.Generic.List[string]]::new()
 foreach($entry in @($entries | Sort-Object Order,Slug)){
  $href=if($entry.Slug -eq 'index'){$prefix+'index.html'}else{$prefix+$entry.Slug+'/'}
  $current=if($entry.Slug -eq $active){' aria-current="page"'}else{''}
  $links.Add('<a href="'+(Escape $href)+'"'+$current+'>'+(Escape $entry.Title)+'</a>')
 }
 if($blogEnabled){
  $current=if($active -eq 'blog'){' aria-current="page"'}else{''}
  $links.Add('<a href="'+(Escape ($prefix+'posts.html'))+'"'+$current+'>Blog</a>')
 }
 return ($links.ToArray() -join ' ')
}

function Render-ZetaPages([string]$name,[string]$stage,[hashtable]$c,[bool]$blogEnabled){
 $site=SiteDir $name
 $pages=Join-Path $site 'pages'
 $sourceFiles=@(Get-ChildItem -LiteralPath $pages -Filter '*.md' -File | Sort-Object Name)
 foreach($file in $sourceFiles){
  $slug=$file.BaseName
  if($slug -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$' -or $slug -in @('posts','blog')){throw "Invalid or reserved Markdown page: $slug"}
  if((Meta $file.FullName draft) -eq 'true'){
   if($slug -eq 'index'){throw 'The homepage cannot be a draft'}
   continue
  }
  $root=if($slug -eq 'index'){''}else{'../'}
  $dest=if($slug -eq 'index'){Join-Path $stage 'index.html'}else{Join-Path $stage "$slug/index.html"}
  $heading=Meta $file.FullName title
  if(-not $heading){$heading=$slug}
  $desc=Meta $file.FullName description
  if(-not $desc){$desc=$c.description}
  $pageNavigation=Get-ZetaPageNavigation $name $root $slug $blogEnabled
  $canonical=if($slug -eq 'index'){$c.url.TrimEnd('/')+'/'}else{$c.url.TrimEnd('/')+'/'+$slug+'/'}
  [void](New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force)
  $depth=if($slug -eq 'index'){'0'}else{'1'}
  $pageTemplate=Join-Path $Templates 'common/pages/page.html'
  $pageFilter=Join-Path $Templates 'common/filters/page-links.lua'
  if(-not (Test-Path -LiteralPath $pageTemplate -PathType Leaf)){throw "Page template missing: $pageTemplate"}
  if(-not (Test-Path -LiteralPath $pageFilter -PathType Leaf)){throw "Page Lua filter missing: $pageFilter"}
  # Construct each Pandoc argument as a *complete* string. Concatenating
  # an expression directly inside @() can produce a bare --lua-filter=.
  $filterArgument="--lua-filter=$pageFilter"
  $opts=@($file.FullName,'-f','markdown-raw_html','-t','html5','--standalone','--wrap=none',
    '--template',$pageTemplate,
    $filterArgument,
    '-M',('zeta_page_depth='+$depth),
    '-V',('title='+(Escape $heading)),'-V',('description='+(Escape $desc)),
    '-V',('site_title='+(Escape $c.title)),'-V',('site_author='+(Escape $c.author)),
    '-V',('site_lang='+(Escape $c.language)),'-V',('site_theme='+(Escape $c.theme)),
    '-V',('page_slug='+(Escape $slug)),'-V',('canonical='+(Escape $canonical)),
    '-V',('rel_root='+$root),'-V',('page_navigation='+$pageNavigation))
   $opts+=@(Styles $c.theme $site $root)
   $opts+=@('-o',$dest)
  if($opts -contains '--lua-filter=' -or $opts -contains ''){throw "Pandoc received an empty argument for page: $slug"}
  Invoke-ZetaPandoc $opts
 }
}

# Supply an initial Markdown homepage for an existing/partially-created pages folder.
function Ensure-ZetaPageHome([string]$name){
 $site=SiteDir $name
 $pages=Join-Path $site 'pages'
 if(-not (Test-Path -LiteralPath $pages -PathType Container)){return}
 $pageInfo=Get-Item -LiteralPath $pages -Force
 if($pageInfo.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Unsafe pages directory: $pages"}
 $homepagePath=Join-Path $pages 'index.md'
 if(Test-Path -LiteralPath $homepagePath){
  if((Get-Item -LiteralPath $homepagePath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Unsafe homepage: $homepagePath"}
  [void](Repair-ZetaGeneratedHomepageYaml $homepagePath)
  return
 }
 $template=Join-Path $Templates 'common/pages/index.md'
 if(-not (Test-Path -LiteralPath $template -PathType Leaf)){throw "Missing homepage template: $template"}
 $c=Config $name
 $body=[IO.File]::ReadAllText($template)
 if(-not $body.Contains('__ZETA_SITE_TITLE__') -or -not $body.Contains('__ZETA_SITE_DESCRIPTION__')){throw 'Homepage template has invalid placeholders'}
 $body=$body.Replace('__ZETA_SITE_TITLE__',(Quote $c.title)).Replace('__ZETA_SITE_DESCRIPTION__',(Quote $c.description))
 try {
  $writer=[IO.StreamWriter]::new([IO.FileStream]::new($homepagePath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None),$Utf8)
  try{$writer.Write($body)}finally{$writer.Dispose()}
 }catch [IO.IOException]{
  if(-not (Test-Path -LiteralPath $homepagePath -PathType Leaf)){throw}
 }
 Write-Host "[INFO] Initialized Markdown homepage: $homepagePath" -ForegroundColor Cyan
}


# Historical Zeta builds wrote title: ""Title"" in pages/index.md.
# Repair only that precise invalid frontmatter pattern, preserving article
# content, YAML ordering, existing single quotes and line endings.
function Repair-ZetaGeneratedHomepageYaml([string]$homepagePath){
 if(-not (Test-Path -LiteralPath $homepagePath -PathType Leaf)){return $false}
 $original=[IO.File]::ReadAllText($homepagePath)
 if($original -notmatch '\A---\r?\n'){return $false}
 $closing=[regex]::Match($original,'(?m)^---\r?$',[Text.RegularExpressions.RegexOptions]::None,[TimeSpan]::FromSeconds(1))
 # Find the delimiter after the opening --- (not the delimiter at offset zero).
 $tail=[regex]::Match($original.Substring(4),'(?m)^---\r?$',[Text.RegularExpressions.RegexOptions]::None,[TimeSpan]::FromSeconds(1))
 if(-not $tail.Success){return $false}
 $frontmatterEnd=4+$tail.Index
 $frontmatter=$original.Substring(0,$frontmatterEnd)
 $body=$original.Substring($frontmatterEnd)
 $pattern='(?m)^(title|description):[ \t]*""([^"\r\n]*)""(?=\r?$)'
 $fixed=[regex]::Replace($frontmatter,$pattern,[Text.RegularExpressions.MatchEvaluator]{
  param($m)
  return $m.Groups[1].Value+': "'+$m.Groups[2].Value+'"'
 })
 if($fixed -ceq $frontmatter){return $false}
 $backup="$homepagePath.zeta-backup-$([guid]::NewGuid().ToString('N')).bak"
 Copy-Item -LiteralPath $homepagePath -Destination $backup -ErrorAction Stop
 try{
  [IO.File]::WriteAllText($homepagePath,($fixed+$body),$Utf8)
 }catch{
  Copy-Item -LiteralPath $backup -Destination $homepagePath -Force
  throw
 }
 Write-Warning "Repaired duplicate-quote YAML in $homepagePath. Original saved to $backup"
 return $true
}
){throw 'Invalid site.language (e.g. en or es-ES)'}
 if($c.url -notmatch '^https?://[^\s?#]+$'){throw 'Invalid production URL'}
 if(-not (SafeDir $c.content)){throw "Unsafe build.content_dir '$($c.content)' in $(ConfigPath $name): expected relative path such as posts."}
 if(-not (SafeDir $c.output)){throw "Unsafe build.output_dir '$($c.output)' in $(ConfigPath $name): expected relative path such as public."}
 $content=$c.content.Replace('\','/').Trim('/');$output=$c.output.Replace('\','/').Trim('/')
 if($content -eq $output -or $content.StartsWith("$output/") -or $output.StartsWith("$content/")){throw 'Build directory overlap'}
 if((Themes) -notcontains $c.theme){throw "Unknown theme: $($c.theme)"}
 $theme=Join-Path -Path $Templates -ChildPath $c.theme
 $articleTemplate=Get-ZetaTemplate $theme 'article.html'
 $cardTemplate=Get-ZetaTemplate $theme 'post_link.html'
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
 $files=@(Posts $name)
 if(Test-Path -LiteralPath (Join-Path $dir 'pages') -PathType Container){
  Ensure-ZetaPageHome $name
 }
 if((Test-Path -LiteralPath (Join-Path $dir 'pages/index.md') -PathType Leaf) -and
    ((Yaml (ConfigPath $name) build blog 'true') -eq 'false')){$files=@()}
 $hasMarkdownPages=Test-Path -LiteralPath (Join-Path $dir 'pages/index.md') -PathType Leaf
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
   $pandocOptions=@($file.FullName,'-f','markdown+autolink_bare_uris','-t','html5','--standalone','--section-divs','--wrap=none',
      '--table-of-contents','--toc-depth=3','--preserve-tabs','--template',$articleTemplate,
      '-V','rel_root=../../','-V',"title=$(Escape $p.title)",'-V',"author=$(Escape $p.author)",
      '-V',"date=$(Escape $p.human)",'-V',"iso_date=$(Escape $p.date)",'-V',"year=$($p.year)",
      '-V',"slug=$($p.slug)",'-V',"description=$(Escape $p.description)",'-V',"site_title=$(Escape $c.title)",
      '-V',"site_author=$(Escape $c.author)",'-V',"site_lang=$(Escape $c.language)",
      "$hflag=$($c.highlight)")
   $filter=Join-Path $Templates 'common/filters/table-wrapper.lua'
   if(Test-Path $filter){$pandocOptions+="--lua-filter=$filter"}
   if($hasMarkdownPages){$pandocOptions+=@('-V',('page_navigation='+(Get-ZetaPageNavigation $name '../../' 'blog' $true)))}
   $pandocOptions+=@(Styles $c.theme $dir '../../')
   foreach($tag in $p.tags){$pandocOptions+=@('-V',('tags='+(Escape $tag)))}
   $pandocOptions+=@('-o',$target)
   Invoke-ZetaPandoc $pandocOptions
   $pandocOptions=@('-f','markdown','-t','html5','--standalone','--quiet','--template',$cardTemplate,
      '-V',"title=$(Escape $p.title)",'-V',"date=$(Escape $p.human)",'-V',"iso_date=$(Escape $p.date)",
      '-V',"path=$rel",'-V',"description=$(Escape $p.description)",'-V',"external_url=$(Escape $p.external_url)")
   $item=('' | & pandoc @pandocOptions) -join [Environment]::NewLine
   if($LASTEXITCODE -ne 0){throw "Post card rendering failed for '$($file.Name)' (exit code $LASTEXITCODE)."}
   $links.Add($item)
  }
  $vars=@{site_lang=(Escape $c.language);site_title=(Escape $c.title);site_desc=(Escape $c.description);
    site_author=(Escape $c.author);posts_list=($links -join [Environment]::NewLine);landing_content=$body}
  foreach($k in $extra.Keys){$vars[$k]=Escape $extra[$k]}
  $pagesDir=Join-Path $dir 'pages'
  $pagesMode=Test-Path -LiteralPath (Join-Path $pagesDir 'index.md') -PathType Leaf
  $blogEnabled=(-not $pagesMode) -or ((Yaml (ConfigPath $name) build blog 'true') -ne 'false')
  foreach($tpl in (Get-ChildItem $theme -Filter '*.html' -File)){
   if($pagesMode -and ($tpl.Name -eq 'index.html' -or (-not $blogEnabled -and $tpl.Name -eq 'posts.html'))){continue}
   if($tpl.Name -in @('article.html','post_link.html')){continue}
   $pageTemplate=Get-ZetaTemplate $theme $tpl.Name
   $pandocOptions=@('-f','markdown','-t','html5','--standalone','--quiet','--template',$pageTemplate)
   foreach($k in $vars.Keys){$pandocOptions+=@('-V',('{0}={1}' -f $k,$vars[$k]))}
   if($pagesMode -and $tpl.Name -eq 'posts.html'){
    $pandocOptions+=@('-V',('page_navigation='+(Get-ZetaPageNavigation $name './' 'blog' $blogEnabled)))
   }
   $pandocOptions+=@(Styles $c.theme $dir '')
   $pandocOptions+=@('-o',(Join-Path $stage $tpl.Name))
   Invoke-ZetaPandoc $pandocOptions
  }
  if($pagesMode){Render-ZetaPages $name $stage $c $blogEnabled}
  if(!(Test-Path (Join-Path $stage 'index.html'))){throw 'Theme did not generate index'}
  $base=$c.url.TrimEnd('/')
  $robot=[IO.File]::ReadAllText((Join-Path $Templates 'robots.txt')).Replace('{{BASE_URL}}',$base)
  Save (Join-Path $stage 'robots.txt') $robot
  $xsl=Join-Path $theme 'sitemap.xsl'
  if(!(Test-Path $xsl)){$xsl=Join-Path $Templates 'common/sitemap.xsl'}
  Copy-Item $xsl (Join-Path $stage 'sitemap.xsl') -Force
  $today=Get-Date -Format yyyy-MM-dd
  $locs=@("$base/")
  if($blogEnabled){$locs+="$base/posts.html"}
  if($blogEnabled){foreach($file in $files){$p=PostInfo $file $c.author;$locs+="$base/posts/$($p.year)/$($p.slug).html"}}
  if($pagesMode){
   foreach($file in @(Get-ChildItem $pagesDir -Filter '*.md' -File)){
    if($file.BaseName -eq 'index' -or (Meta $file.FullName draft) -eq 'true'){continue}
    $locs+="$base/$($file.BaseName)/"
   }
  }
  $rows=foreach($loc in $locs){"<url><loc>$(Xml $loc)</loc><lastmod>$today</lastmod></url>"}
  $xml='<?xml version="1.0" encoding="UTF-8"?>'+[Environment]::NewLine+
    '<?xml-stylesheet type="text/xsl" href="sitemap.xsl"?>'+[Environment]::NewLine+
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+
    ($rows -join [Environment]::NewLine)+'</urlset>'
  Save (Join-Path $stage 'sitemap.xml') $xml
  # Generate the taxonomy archives before shared SEO.
  if($blogEnabled){
   $taxPath=Join-Path $stage '.zeta-taxonomy.tsv'
   $taxonomyRows=[Collections.Generic.List[string]]::new()
   foreach($file in $files){
    $post=PostInfo $file $c.author
    $route="posts/$($post.year)/$($post.slug).html"
    $category=Meta $file.FullName category
    if($category){
     $term=Slug $category
     if(!$term){throw "Invalid category: $($file.FullName)"}
     $taxonomyRows.Add((@($route,'category',$term,$category) -join [char]9))
    }
    foreach($tag in @($post.tags)){
     if(!$tag){continue}
     $term=Slug $tag
     if(!$term){throw "Invalid tag: $($file.FullName)"}
     $taxonomyRows.Add((@($route,'tag',$term,$tag) -join [char]9))
    }
   }
   if($taxonomyRows.Count -gt 0){
    Save $taxPath ($taxonomyRows -join [Environment]::NewLine)
    $filter=Join-Path $Templates 'common/filters/taxonomies.lua'
    if(!(Test-Path -LiteralPath $filter)){throw "Missing taxonomy filter: $filter"}
    $temporary=[IO.Path]::GetTempFileName()
    try{
     $pandocArgs=@('-f','markdown','-t','plain',("--lua-filter=$filter"),'-M',("zeta_taxonomy_output=$stage"),'-M',("zeta_taxonomy_url=$($c.url.TrimEnd('/'))"),'-M',("zeta_taxonomy_title=$($c.title)"),'-M',("zeta_taxonomy_language=$($c.language)"),'-o',$temporary)
     $null=@('' | & pandoc @pandocArgs)
     if($LASTEXITCODE -ne 0){throw 'Taxonomy generation failed'}
    }finally{Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue}
    Remove-Item -LiteralPath $taxPath -Force
   }
  }
  # Apply shared SEO before replacing public/.
  $seoFilter=Join-Path $Templates 'common/filters/seo-publish.lua'
  if(!(Test-Path -LiteralPath $seoFilter -PathType Leaf)){throw "Missing SEO filter: $seoFilter"}
  $seoTmp=[IO.Path]::GetTempFileName()
  try{
   $seoArgs=@('-f','markdown','-t','plain',("--lua-filter=$seoFilter"),'-M',("zeta_seo_output=$stage"),'-M',("zeta_seo_url=$($c.url.TrimEnd('/'))"),'-M',("zeta_seo_title=$($c.title)"),'-M',("zeta_seo_description=$($c.description)"),'-M',("zeta_seo_image=$(Yaml (ConfigPath $name) site image '')"),'-o',$seoTmp)
   $null=@('' | & pandoc @seoArgs)
   if($LASTEXITCODE -ne 0){throw 'Shared SEO generation failed; existing public/ was preserved'}
  }finally{Remove-Item -LiteralPath $seoTmp -Force -ErrorAction SilentlyContinue}
  # Only explicit editorial updated dates are used for sitemap lastmod.
  $updates=Join-Path $stage '.zeta-updates.tsv'
  $dateRows=[Collections.Generic.List[string]]::new()
  if($pagesMode){
   foreach($file in @(Get-ChildItem $pagesDir -Filter '*.md' -File)){
    if((Meta $file.FullName draft) -eq 'true'){continue}
    $updated=Meta $file.FullName updated
    if(!$updated){continue}
    if($updated -notmatch '^\d{4}-\d{2}-\d{2}$'){throw "Invalid updated date in $($file.FullName)"}
    $route=if($file.BaseName -eq 'index'){'index.html'}else{$file.BaseName+'/index.html'}
    $dateRows.Add(($route,$updated -join [char]9))
   }
  }
  if($blogEnabled){
   foreach($file in $files){
    $updated=Meta $file.FullName updated
    if(!$updated){continue}
    if($updated -notmatch '^\d{4}-\d{2}-\d{2}$'){throw "Invalid updated date in $($file.FullName)"}
    $post=PostInfo $file $c.author
    $dateRows.Add((("posts/{0}/{1}.html" -f $post.year,$post.slug),$updated -join [char]9))
   }
  }
  Save $updates ($dateRows -join [Environment]::NewLine)
  $extrasFilter=Join-Path $Templates 'common/filters/publish-extras.lua'
  if(!(Test-Path -LiteralPath $extrasFilter -PathType Leaf)){throw "Missing publishing filter: $extrasFilter"}
  $extrasTemp=[IO.Path]::GetTempFileName()
  try{
   $extrasArgs=@('-f','markdown','-t','plain',("--lua-filter=$extrasFilter"),'-M',("zeta_extra_output=$stage"),'-M',("zeta_extra_url=$($c.url.TrimEnd('/'))"),'-M',("zeta_extra_title=$($c.title)"),'-M',("zeta_extra_description=$($c.description)"),'-M',("zeta_extra_author=$($c.author)"),'-M',("zeta_extra_language=$($c.language)"),'-M',("zeta_extra_blog=$($blogEnabled.ToString().ToLowerInvariant())"),'-o',$extrasTemp)
   $null=@('' | & pandoc @extrasArgs)
   if($LASTEXITCODE -ne 0){throw 'RSS/Atom, structured data or sitemap generation failed'}
  }finally{Remove-Item -LiteralPath $extrasTemp -Force -ErrorAction SilentlyContinue}
  Remove-Item -LiteralPath $updates -Force

  if(Test-Path $previous){Remove-Item $previous -Recurse -Force}
  if(Test-Path $final){Move-Item $final $previous}
  try{Move-Item $stage $final}catch{if(Test-Path $previous){Move-Item $previous $final};throw}
  if(Test-Path $previous){Remove-Item $previous -Recurse -Force}
  Write-Host "[OK] $name : $($files.Count) articles" -ForegroundColor Green
 } finally {if(Test-Path $stage){Remove-Item $stage -Recurse -Force}}
}


# Shared Markdown pages are compiled inside Build's staging directory.
function Get-ZetaPageNavigation([string]$name,[string]$prefix,[string]$active,[bool]$blogEnabled) {
 $pages=Join-Path (SiteDir $name) 'pages'
 $entries=[Collections.Generic.List[object]]::new()
 foreach($file in @(Get-ChildItem -LiteralPath $pages -Filter '*.md' -File)) {
  $slug=$file.BaseName
  if($slug -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$' -or $slug -in @('posts','blog')){throw "Invalid page: $slug"}
  if((Meta $file.FullName draft) -eq 'true' -or (Meta $file.FullName nav) -eq 'false'){continue}
  $title=Meta $file.FullName menu_title
  if(!$title){$title=Meta $file.FullName title}
  if(!$title){$title=$slug}
  $order=50;$raw=Meta $file.FullName nav_order
  if($raw -match '^\d{1,3}$'){$order=[int]$raw}
  if($slug -eq 'index'){$order=0}
  $entries.Add([pscustomobject]@{Slug=$slug;Title=$title;Order=$order})
 }
 $links=[Collections.Generic.List[string]]::new()
 foreach($entry in @($entries | Sort-Object Order,Slug)){
  $href=if($entry.Slug -eq 'index'){$prefix+'index.html'}else{$prefix+$entry.Slug+'/'}
  $current=if($entry.Slug -eq $active){' aria-current="page"'}else{''}
  $links.Add('<a href="'+(Escape $href)+'"'+$current+'>'+(Escape $entry.Title)+'</a>')
 }
 if($blogEnabled){
  $current=if($active -eq 'blog'){' aria-current="page"'}else{''}
  $links.Add('<a href="'+(Escape ($prefix+'posts.html'))+'"'+$current+'>Blog</a>')
 }
 return ($links.ToArray() -join ' ')
}

function Render-ZetaPages([string]$name,[string]$stage,[hashtable]$c,[bool]$blogEnabled){
 $site=SiteDir $name
 $pages=Join-Path $site 'pages'
 $sourceFiles=@(Get-ChildItem -LiteralPath $pages -Filter '*.md' -File | Sort-Object Name)
 foreach($file in $sourceFiles){
  $slug=$file.BaseName
  if($slug -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$' -or $slug -in @('posts','blog')){throw "Invalid or reserved Markdown page: $slug"}
  if((Meta $file.FullName draft) -eq 'true'){
   if($slug -eq 'index'){throw 'The homepage cannot be a draft'}
   continue
  }
  $root=if($slug -eq 'index'){''}else{'../'}
  $dest=if($slug -eq 'index'){Join-Path $stage 'index.html'}else{Join-Path $stage "$slug/index.html"}
  $heading=Meta $file.FullName title
  if(-not $heading){$heading=$slug}
  $desc=Meta $file.FullName description
  if(-not $desc){$desc=$c.description}
  $pageNavigation=Get-ZetaPageNavigation $name $root $slug $blogEnabled
  $canonical=if($slug -eq 'index'){$c.url.TrimEnd('/')+'/'}else{$c.url.TrimEnd('/')+'/'+$slug+'/'}
  [void](New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force)
  $depth=if($slug -eq 'index'){'0'}else{'1'}
  $pageTemplate=Join-Path $Templates 'common/pages/page.html'
  $pageFilter=Join-Path $Templates 'common/filters/page-links.lua'
  if(-not (Test-Path -LiteralPath $pageTemplate -PathType Leaf)){throw "Page template missing: $pageTemplate"}
  if(-not (Test-Path -LiteralPath $pageFilter -PathType Leaf)){throw "Page Lua filter missing: $pageFilter"}
  # Construct each Pandoc argument as a *complete* string. Concatenating
  # an expression directly inside @() can produce a bare --lua-filter=.
  $filterArgument="--lua-filter=$pageFilter"
  $opts=@($file.FullName,'-f','markdown-raw_html','-t','html5','--standalone','--wrap=none',
    '--template',$pageTemplate,
    $filterArgument,
    '-M',('zeta_page_depth='+$depth),
    '-V',('title='+(Escape $heading)),'-V',('description='+(Escape $desc)),
    '-V',('site_title='+(Escape $c.title)),'-V',('site_author='+(Escape $c.author)),
    '-V',('site_lang='+(Escape $c.language)),'-V',('site_theme='+(Escape $c.theme)),
    '-V',('page_slug='+(Escape $slug)),'-V',('canonical='+(Escape $canonical)),
    '-V',('rel_root='+$root),'-V',('page_navigation='+$pageNavigation))
   $opts+=@(Styles $c.theme $site $root)
   $opts+=@('-o',$dest)
  if($opts -contains '--lua-filter=' -or $opts -contains ''){throw "Pandoc received an empty argument for page: $slug"}
  Invoke-ZetaPandoc $opts
 }
}

# Supply an initial Markdown homepage for an existing/partially-created pages folder.
function Ensure-ZetaPageHome([string]$name){
 $site=SiteDir $name
 $pages=Join-Path $site 'pages'
 if(-not (Test-Path -LiteralPath $pages -PathType Container)){return}
 $pageInfo=Get-Item -LiteralPath $pages -Force
 if($pageInfo.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Unsafe pages directory: $pages"}
 $homepagePath=Join-Path $pages 'index.md'
 if(Test-Path -LiteralPath $homepagePath){
  if((Get-Item -LiteralPath $homepagePath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Unsafe homepage: $homepagePath"}
  [void](Repair-ZetaGeneratedHomepageYaml $homepagePath)
  return
 }
 $template=Join-Path $Templates 'common/pages/index.md'
 if(-not (Test-Path -LiteralPath $template -PathType Leaf)){throw "Missing homepage template: $template"}
 $c=Config $name
 $body=[IO.File]::ReadAllText($template)
 if(-not $body.Contains('__ZETA_SITE_TITLE__') -or -not $body.Contains('__ZETA_SITE_DESCRIPTION__')){throw 'Homepage template has invalid placeholders'}
 $body=$body.Replace('__ZETA_SITE_TITLE__',(Quote $c.title)).Replace('__ZETA_SITE_DESCRIPTION__',(Quote $c.description))
 try {
  $writer=[IO.StreamWriter]::new([IO.FileStream]::new($homepagePath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None),$Utf8)
  try{$writer.Write($body)}finally{$writer.Dispose()}
 }catch [IO.IOException]{
  if(-not (Test-Path -LiteralPath $homepagePath -PathType Leaf)){throw}
 }
 Write-Host "[INFO] Initialized Markdown homepage: $homepagePath" -ForegroundColor Cyan
}


# Historical Zeta builds wrote title: ""Title"" in pages/index.md.
# Repair only that precise invalid frontmatter pattern, preserving article
# content, YAML ordering, existing single quotes and line endings.
function Repair-ZetaGeneratedHomepageYaml([string]$homepagePath){
 if(-not (Test-Path -LiteralPath $homepagePath -PathType Leaf)){return $false}
 $original=[IO.File]::ReadAllText($homepagePath)
 if($original -notmatch '\A---\r?\n'){return $false}
 $closing=[regex]::Match($original,'(?m)^---\r?$',[Text.RegularExpressions.RegexOptions]::None,[TimeSpan]::FromSeconds(1))
 # Find the delimiter after the opening --- (not the delimiter at offset zero).
 $tail=[regex]::Match($original.Substring(4),'(?m)^---\r?$',[Text.RegularExpressions.RegexOptions]::None,[TimeSpan]::FromSeconds(1))
 if(-not $tail.Success){return $false}
 $frontmatterEnd=4+$tail.Index
 $frontmatter=$original.Substring(0,$frontmatterEnd)
 $body=$original.Substring($frontmatterEnd)
 $pattern='(?m)^(title|description):[ \t]*""([^"\r\n]*)""(?=\r?$)'
 $fixed=[regex]::Replace($frontmatter,$pattern,[Text.RegularExpressions.MatchEvaluator]{
  param($m)
  return $m.Groups[1].Value+': "'+$m.Groups[2].Value+'"'
 })
 if($fixed -ceq $frontmatter){return $false}
 $backup="$homepagePath.zeta-backup-$([guid]::NewGuid().ToString('N')).bak"
 Copy-Item -LiteralPath $homepagePath -Destination $backup -ErrorAction Stop
 try{
  [IO.File]::WriteAllText($homepagePath,($fixed+$body),$Utf8)
 }catch{
  Copy-Item -LiteralPath $backup -Destination $homepagePath -Force
  throw
 }
 Write-Warning "Repaired duplicate-quote YAML in $homepagePath. Original saved to $backup"
 return $true
}
