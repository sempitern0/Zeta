# Zeta PowerShell: read-only deployment diagnostics (same checks as Bash doctor).
function DoctorStatus([hashtable]$state,[string]$level,[string]$label,[string]$detail){
 if($level -eq 'FAIL'){$state.errors++;$color='Red'}
 elseif($level -eq 'WARN'){$state.warnings++;$color='Yellow'}
 else{$color='Green'}
 Write-Host ('  [{0,-4}] {1,-21} {2}' -f $level,$label,$detail) -ForegroundColor $color
}
function Doctor([string]$name){
 $configPath=ConfigPath $name
 $siteDir=SiteDir $name
 $state=@{errors=0;warnings=0}
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
   if($posts.Count){DoctorStatus $state OK 'Posts' ("{0} Markdown file(s)" -f $posts.Count)}
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
 Write-Host 'Generated deploy artifact' -ForegroundColor White
 if($validOutput){
  $outputDir=Join-Path $siteDir $output
  if(Test-Path -LiteralPath $outputDir -PathType Container){
   DoctorStatus $state OK 'public/' $outputDir
   foreach($file in @('index.html','posts.html','robots.txt','sitemap.xml')){
    $target=Join-Path $outputDir $file
    $present=(Test-Path -LiteralPath $target -PathType Leaf)
    if($present){$present=(Get-Item -LiteralPath $target).Length -gt 0}
    if($present){DoctorStatus $state OK $file 'present'}
    elseif($file -eq 'posts.html'){DoctorStatus $state WARN $file 'missing or empty'}
    else{DoctorStatus $state FAIL $file 'missing or empty'}
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
 if($state.errors){
  Write-Host ("Doctor found {0} blocking issue(s), {1} warning(s)." -f $state.errors,$state.warnings) -ForegroundColor Red
  throw 'Site is not ready for deployment'
 }
 if($state.warnings){
  Write-Host ("Doctor found no blocking issues and {0} warning(s)." -f $state.warnings) -ForegroundColor Yellow
 }else{Write-Host 'Doctor: site is ready for deployment.' -ForegroundColor Green}
}
