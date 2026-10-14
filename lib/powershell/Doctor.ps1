# Zeta PowerShell: read-only deployment diagnostics (same checks as Bash doctor).
function DoctorCategory([string]$label){
 if($label -match '(?i)link|image|unsafe_url|asset'){return 'Links & assets'}
 if($label -match '(?i)canonical|description|html_title|html_lang|og:|seo|site.url|metadata'){return 'SEO & metadata'}
 if($label -match '(?i)sitemap|robots|public/|freshness|artifact|output_checked|published html'){return 'Publishing'}
 if($label -match '(?i)markdown|post|page|source|homepage|draft'){return 'Content'}
 return 'Configuration'
}
function DoctorStatus([hashtable]$state,[string]$level,[string]$label,[string]$detail){
 if($level -eq 'FAIL'){$state.errors++;$color='Red';if($state.ContainsKey('findings')){$state.findings.Add($label)}}
 elseif($level -eq 'WARN'){$state.warnings++;$color='Yellow';if($state.ContainsKey('findings')){$state.findings.Add($label)}}
 if($level -in @('FAIL','WARN') -and $state.ContainsKey('categories')){
  $group=DoctorCategory $label
  $state.categories[$group]=1+$state.categories[$group]
 }
 else{$color='Green'}
 Write-Host ('  [{0,-4}] {1,-21} {2}' -f $level,$label,$detail) -ForegroundColor $color
}
function Doctor([string]$name){
 $configPath=ConfigPath $name
 $siteDir=SiteDir $name
 $state=@{errors=0;warnings=0;findings=[Collections.Generic.List[string]]::new();categories=@{'Links & assets'=0;'SEO & metadata'=0;Publishing=0;Content=0;Configuration=0}}
 Write-Host ''
 Write-Host ("ZETA / Doctor: {0}" -f $name) -ForegroundColor Cyan
 Write-Host ('-'*65) -ForegroundColor DarkGray
 $title=Yaml $configPath site title ''
 $description=Yaml $configPath site description ''
 $author=Yaml $configPath site author ''
 $lang=Yaml $configPath site language ''
 $url=Yaml $configPath site url ''
 $theme=Yaml $configPath theme name ''
 $highlight=Yaml $configPath theme pandoc_theme ''
 $content=Yaml $configPath build content_dir ''
 $output=Yaml $configPath build output_dir ''
 $pageDir=Join-Path $siteDir 'pages'
 $pageMode=Test-Path -LiteralPath (Join-Path $pageDir 'index.md') -PathType Leaf
 $blogEnabled=(-not $pageMode) -or ((Yaml $configPath build blog 'true') -ne 'false')
 Write-Host 'Configuration' -ForegroundColor White
 if($title){DoctorStatus $state OK 'site.title' $title}
 else{DoctorStatus $state FAIL 'site.title' 'missing'}
 if($description){DoctorStatus $state OK 'site.description' $description}
 else{DoctorStatus $state WARN 'site.description' 'missing'}
 if($author){DoctorStatus $state OK 'site.author' $author}
 else{DoctorStatus $state WARN 'site.author' 'missing'}
 if($lang -match '^[A-Za-z]{2,3}([_-][A-Za-z0-9]{2,8})*$'){
  DoctorStatus $state OK 'site.language' $lang
 }else{DoctorStatus $state FAIL 'site.language' 'invalid or missing'}
 $validUrl=$url -match '^https?://[^\s?#]+$'
 if(!$validUrl){DoctorStatus $state FAIL 'site.url' 'invalid or missing absolute URL'}
 elseif($url -match '^https?://example\.com(/|$)'){
  DoctorStatus $state WARN 'site.url' 'placeholder URL'
 }elseif($url.StartsWith('http://')){
  DoctorStatus $state WARN 'site.url' 'HTTP; HTTPS recommended'
 }else{DoctorStatus $state OK 'site.url' $url}
 if(@(Themes) -contains $theme){DoctorStatus $state OK 'theme.name' $theme}
 else{DoctorStatus $state FAIL 'theme.name' 'unknown theme'}
 $pandoc=Get-Command pandoc -ErrorAction SilentlyContinue
 if($pandoc){
  $styles=@(& pandoc --list-highlight-styles 2>$null)
  if($LASTEXITCODE -eq 0 -and $styles -contains $highlight){
   DoctorStatus $state OK 'pandoc_theme' $highlight
  }else{DoctorStatus $state FAIL 'pandoc_theme' 'unknown highlighting style'}
 }else{DoctorStatus $state WARN 'pandoc_theme' 'cannot verify without Pandoc'}
 $validContent=SafeDir $content
 $validOutput=SafeDir $output
 if($validContent){DoctorStatus $state OK 'content_dir' $content}
 else{DoctorStatus $state FAIL 'content_dir' 'unsafe or missing'}
 if($validOutput){DoctorStatus $state OK 'output_dir' $output}
 else{DoctorStatus $state FAIL 'output_dir' 'unsafe or missing'}
 if($validContent -and $validOutput){
  $c=$content.Replace('\','/').Trim('/')
  $o=$output.Replace('\','/').Trim('/')
  if($c -eq $o -or $c.StartsWith("$o/") -or $o.StartsWith("$c/")){
   DoctorStatus $state FAIL 'Build paths' 'content and output directories overlap'
  }else{DoctorStatus $state OK 'Build paths' 'separate directories'}
 }
 Write-Host ''
 Write-Host 'Runtime and content' -ForegroundColor White
 if($pandoc){
  $version=(& pandoc --version | Select-Object -First 1)
  DoctorStatus $state OK 'Pandoc' $version
 }else{DoctorStatus $state FAIL 'Pandoc' 'not installed'}
 DoctorStatus $state OK 'Preview runtime' 'PowerShell 7+ / .NET HttpListener'
 $contentDir=$null
 $posts=@()
 if($validContent){
  $contentDir=Join-Path $siteDir $content
  if(Test-Path -LiteralPath $contentDir -PathType Container){
   $posts=@(Get-ChildItem -LiteralPath $contentDir -File -Recurse -Filter '*.md')
   if(-not $blogEnabled){
    DoctorStatus $state OK 'Blog' 'disabled by site configuration'
   }elseif($posts.Count){DoctorStatus $state OK 'Posts' ("{0} Markdown file(s)" -f $posts.Count)}
   else{DoctorStatus $state WARN 'Posts' 'no Markdown posts found'}
   $routes=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
   $duplicate=$null
   foreach($file in $posts){
    $p=PostInfo $file $author
    $route="posts/$($p.year)/$($p.slug).html"
    if(!$routes.Add($route)){$duplicate=$route;break}
   }
   if($duplicate){DoctorStatus $state FAIL 'Post routes' ("duplicate: {0}" -f $duplicate)}
   else{DoctorStatus $state OK 'Post routes' 'no duplicate generated routes'}
  }else{DoctorStatus $state FAIL 'Posts' 'content directory missing'}
 }
 Write-Host ''
 Write-Host 'Markdown integrity' -ForegroundColor White
 $filter=Join-Path $Templates 'common/filters/doctor-links.lua'
 if($pandoc -and (Test-Path $filter)){
  $sourceFiles=@()
  if($validContent -and (Test-Path $contentDir)){$sourceFiles+=@(Get-ChildItem $contentDir -Filter '*.md' -Recurse -File)}
  if(Test-Path $pageDir){
   $sourceFiles+=@(Get-ChildItem $pageDir -Filter '*.md' -File)
   if(!$pageMode){DoctorStatus $state FAIL 'Homepage' 'pages/index.md missing'}
  }
  foreach($sourceFile in $sourceFiles){
   $tmp=[IO.Path]::GetTempFileName()
   try{
    $args=@($sourceFile.FullName,'-f','markdown','-t','plain',("--lua-filter=$filter"),'-M',("zeta_doctor_source=$($sourceFile.FullName)"),'-M',("zeta_doctor_site=$siteDir"),'-o',$tmp)
    $lines=@(& pandoc @args 2>&1 | ForEach-Object {[string]$_})
    $rc=$LASTEXITCODE
    foreach($line in $lines){
     if($line -match '^ZETA_DOCTOR\|(FAIL|WARN)\|([^|]+)\|(.*)$'){
      DoctorStatus $state $Matches[1] $Matches[2] ($sourceFile.Name+': '+$Matches[3])
     }elseif($rc -ne 0 -and $line.Trim()){DoctorStatus $state FAIL 'Markdown parse' ($sourceFile.Name+': '+$line)}
    }
    if($rc -ne 0 -and !$lines.Count){DoctorStatus $state FAIL 'Markdown parse' $sourceFile.Name}
   }finally{Remove-Item $tmp -Force -ErrorAction SilentlyContinue}
  }
  DoctorStatus $state OK 'Sources inspected' "$($sourceFiles.Count) Markdown document(s)"
 }elseif(!$pandoc){DoctorStatus $state WARN 'Markdown' 'Pandoc unavailable'}
 else{DoctorStatus $state FAIL 'Markdown' 'doctor-links.lua missing'}
 Write-Host ''
 Write-Host 'Generated deploy artifact' -ForegroundColor White
 if($validOutput){
  $outputDir=Join-Path $siteDir $output
  if(Test-Path -LiteralPath $outputDir -PathType Container){
   DoctorStatus $state OK 'public/' $outputDir
   $required=@('index.html','robots.txt','sitemap.xml')
   if($blogEnabled){$required+= 'posts.html'}
   foreach($file in $required){
    $target=Join-Path $outputDir $file
    $present=(Test-Path -LiteralPath $target -PathType Leaf)
    if($present){$present=(Get-Item -LiteralPath $target).Length -gt 0}
    if($present){DoctorStatus $state OK $file 'present'}
    elseif($file -eq 'posts.html'){DoctorStatus $state WARN $file 'missing or empty'}
    else{DoctorStatus $state FAIL $file 'missing or empty'}
   }
   if($pageMode){
    foreach($page in @(Get-ChildItem -LiteralPath $pageDir -Filter '*.md' -File)){
     if((Meta $page.FullName draft) -eq 'true'){continue}
     $route=if($page.BaseName -eq 'index'){'index.html'}else{$page.BaseName+'/index.html'}
     if(Test-Path -LiteralPath (Join-Path $outputDir $route) -PathType Leaf){
      DoctorStatus $state OK "Page $($page.BaseName)" 'published'
     }else{
      DoctorStatus $state FAIL "Page $($page.BaseName)" 'missing from public/'
     }
    }
   }
   Write-Host ''
   Write-Host 'Published HTML and sitemap' -ForegroundColor White
   $filter=Join-Path $Templates 'common/filters/doctor-public.lua'
   if(!$pandoc){DoctorStatus $state WARN 'Published HTML' 'Pandoc unavailable'}
   elseif(!(Test-Path $filter)){DoctorStatus $state FAIL 'Published HTML' 'doctor-public.lua missing'}
   elseif($validUrl){
    $tmp=[IO.Path]::GetTempFileName()
    try{
     $args=@('-f','markdown','-t','plain',("--lua-filter=$filter"),'-M',("zeta_doctor_output=$outputDir"),'-M',("zeta_doctor_url=$($url.TrimEnd('/'))"),'-o',$tmp)
     $lines=@('' | & pandoc @args 2>&1 | ForEach-Object {[string]$_})
     $rc=$LASTEXITCODE
     foreach($line in $lines){
      if($line -match '^ZETA_DOCTOR\|(FAIL|WARN|OK)\|([^|]+)\|(.*)$'){
       DoctorStatus $state $Matches[1] $Matches[2] $Matches[3]
      }elseif($rc -ne 0 -and $line.Trim()){DoctorStatus $state FAIL 'Published HTML' $line}
     }
     if($rc -ne 0 -and !$lines.Count){DoctorStatus $state FAIL 'Published HTML' 'Lua audit failed'}
    }finally{Remove-Item $tmp -Force -ErrorAction SilentlyContinue}
   }
   $leaks=@(Get-ChildItem -LiteralPath $outputDir -Recurse -File | Where-Object {
    $_.Extension -in @('.md','.markdown') -or $_.Name -in @('config.yaml','config.yml')
   })
   if($leaks.Count){DoctorStatus $state FAIL 'Artifact hygiene' ("{0} source file(s) in output" -f $leaks.Count)}
   else{DoctorStatus $state OK 'Artifact hygiene' 'no Markdown/config sources published'}
   if($contentDir -and (Test-Path -LiteralPath $contentDir -PathType Container)){
    $newestSource=$posts | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    $newestOutput=Get-ChildItem -LiteralPath $outputDir -Recurse -File -Filter '*.html' |
      Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if($newestSource -and (!$newestOutput -or $newestSource.LastWriteTimeUtc -gt $newestOutput.LastWriteTimeUtc)){
     DoctorStatus $state WARN 'Freshness' 'source is newer than generated HTML'
    }else{DoctorStatus $state OK 'Freshness' 'generated HTML is current'}
   }
   $robots=Join-Path $outputDir 'robots.txt'
   if($validUrl -and (Test-Path -LiteralPath $robots -PathType Leaf)){
    $expected='Sitemap: '+$url.TrimEnd('/')+'/sitemap.xml'
    if([IO.File]::ReadAllText($robots).Contains($expected)){
     DoctorStatus $state OK 'robots sitemap' 'matches site.url'
    }else{DoctorStatus $state WARN 'robots sitemap' 'rebuild recommended'}
   }
   $sitemap=Join-Path $outputDir 'sitemap.xml'
   if($validUrl -and (Test-Path -LiteralPath $sitemap -PathType Leaf)){
    $expected='<loc>'+(Xml ($url.TrimEnd('/')+'/'))
    if([IO.File]::ReadAllText($sitemap).Contains($expected)){
     DoctorStatus $state OK 'sitemap URLs' 'match site.url'
    }else{DoctorStatus $state WARN 'sitemap URLs' 'rebuild recommended'}
   }
  }else{DoctorStatus $state WARN 'public/' 'not built yet'}
 }
 Write-Host ''
 Write-Host ('-'*65) -ForegroundColor DarkGray
 $quality=[Math]::Max(0,100-(15*$state.errors)-(3*$state.warnings))
 Write-Host ("Quality snapshot: {0}/100 (errors: {1}; warnings: {2})" -f $quality,$state.errors,$state.warnings) -ForegroundColor Cyan
 if($state.errors -or $state.warnings){
  $ids=@($state.findings | Select-Object -Unique)
  Write-Host ('Priority findings: '+($ids -join ', ')) -ForegroundColor Yellow
  Write-Host 'Issues by category:' -ForegroundColor Yellow
  foreach($group in @($state.categories.Keys | Sort-Object)){
   if($state.categories[$group] -gt 0){Write-Host ('  {0}: {1}' -f $group,$state.categories[$group]) -ForegroundColor Yellow}
  }
  if($ids -match '(?i)link|image|unsafe_url|asset'){
   Write-Host '  Fix local href/src targets and publish missing assets.' -ForegroundColor Yellow
  }
  if($ids -match '(?i)canonical|description|html_title|html_lang|site.url'){
   Write-Host '  Review site.url and Markdown title/description; rebuild to regenerate SEO tags.' -ForegroundColor Yellow
  }
  if($ids -match '(?i)Markdown parse|Homepage|page'){
   Write-Host '  Correct YAML frontmatter and verify pages/index.md before rebuilding.' -ForegroundColor Yellow
  }
  if($ids -match '(?i)sitemap|robots|freshness|public/'){
   Write-Host '  Rebuild the site and check public/sitemap.xml and robots.txt.' -ForegroundColor Yellow
  }
  Write-Host 'Recommended: address FAIL findings before deploying; then review WARN items.' -ForegroundColor Yellow
  Write-Host ("Commands: .\\zeta.ps1 build {0} ; .\\zeta.ps1 doctor {0}" -f $name) -ForegroundColor Gray
 }else{Write-Host 'No corrective actions required by the current checks.' -ForegroundColor Green}
 if($state.errors){
  Write-Host ("Doctor found {0} blocking issue(s), {1} warning(s)." -f $state.errors,$state.warnings) -ForegroundColor Red
  throw 'Site is not ready for deployment'
 }
 if($state.warnings){
  Write-Host ("Doctor found no blocking issues and {0} warning(s)." -f $state.warnings) -ForegroundColor Yellow
 }else{Write-Host 'Doctor: site is ready for deployment.' -ForegroundColor Green}
}
