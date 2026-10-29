# Homepage article feed configuration, preserving site config's unrelated keys.
function Set-ZetaHomepage([string]$name,[string]$mode='',[string]$limit=''){
 $path=ConfigPath $name
 $currentMode=Yaml $path homepage show_posts auto
 $currentLimit=Yaml $path homepage posts_limit '6'
 if(!$mode){
  Write-Host "ZETA / Homepage / $name" -ForegroundColor Cyan
  Write-Host 'auto shows posts on Paper, Gazette and Magazine themes.'
  $mode=Ask 'Show posts (auto/true/false)' $currentMode
  $limit=Ask 'Number of recent articles (1..30)' $currentLimit
 }
 if(!$limit){$limit=$currentLimit}
 if($mode -notin @('auto','true','false')){throw 'Expected auto, true or false'}
 $count=0
 if(-not [int]::TryParse($limit,[ref]$count) -or $count -lt 1 -or $count -gt 30){throw 'Posts limit must be 1..30'}
 $raw=[IO.File]::ReadAllText($path)
 $newline=if($raw.Contains("`r`n")){"`r`n"}else{"`n"}
 $lines=$raw -split '\r?\n'
 $result=[Collections.Generic.List[string]]::new()
 $inside=$false;$found=$false
 foreach($line in $lines){
  if($line -match '^homepage:\s*$'){
   $inside=$true;$found=$true
   $result.Add($line)
   $result.Add("  show_posts: $mode")
   $result.Add("  posts_limit: $count")
   continue
  }
  if($inside -and $line -match '^[^\s#]'){$inside=$false}
  if($inside -and $line -match '^\s+(show_posts|posts_limit):'){continue}
  $result.Add($line)
 }
 if(!$found){
  $result.Add('homepage:')
  $result.Add("  show_posts: $mode")
  $result.Add("  posts_limit: $count")
 }
 Save $path ($result.ToArray() -join $newline)
 Write-Host "[OK] Homepage configured. Rebuild $name to apply." -ForegroundColor Green
}
