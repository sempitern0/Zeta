# Zeta deployment assistant. Configuration is plain key=value data, never executed.
function Get-ZetaDeployFile([string]$name){ [void](ConfigPath $name); Join-Path (SiteDir $name) 'deploy.conf' }
function Read-ZetaDeploy([string]$name){
 $path=Get-ZetaDeployFile $name
 if(!(Test-Path -LiteralPath $path)){throw "Deployment not configured. Run: .\\zeta.ps1 deploy setup $name"}
 $c=@{}
 foreach($line in [IO.File]::ReadAllLines($path)){
  if($line -match '^([a-z]+)=(.*)$'){$c[$Matches[1]]=$Matches[2]}
  elseif($line.Trim()){throw 'Invalid deployment configuration'}
 }
 if($c.provider -notin @('github-pages','cloudflare-pages')){throw 'Invalid provider'}
 if($c.provider -eq 'github-pages'){
  if($c.repository -cnotmatch '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$' -or $c.repository.Contains('..')){throw 'Invalid repository'}
  if($c.branch -cnotmatch '^[a-zA-Z0-9][a-zA-Z0-9_./-]*$' -or $c.branch.Contains('..')){throw 'Invalid branch'}
 }elseif($c.project -cnotmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]*$'){throw 'Invalid Cloudflare project'}
 if($c.account -and $c.account -cnotmatch '^[a-fA-F0-9]{32}$'){throw 'Invalid account ID'}
 return $c
}
function Setup-ZetaDeploy([string]$name){
 [void](ConfigPath $name)
 Write-Host "ZETA / Configure provider for $name" -ForegroundColor Cyan
 $provider=SelectItem 'Provider' @('GitHub Pages','Cloudflare Pages') 'GitHub Pages'
 $key=if($provider -eq 'GitHub Pages'){'github-pages'}else{'cloudflare-pages'}
 $c=@{provider=$key;repository='';branch='';project='';account=''}
 if($key -in @(Get-ZetaProviders $name)){$c=Read-ZetaProvider $name $key}
 if($key -eq 'github-pages'){
  $c.repository=Ask 'GitHub repository (owner/repository)' $c.repository
  $c.branch=Ask 'Publishing branch' $(if($c.branch){$c.branch}else{'gh-pages'})
 }else{
  $c.project=Ask 'Cloudflare Pages project' $c.project
  $c.account=Ask 'Cloudflare account ID (optional)' $c.account
 }
 if($key -eq 'github-pages'){
  if($c.repository -cnotmatch '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$' -or $c.repository.Contains('..')){throw 'Invalid repository'}
  if($c.branch -cnotmatch '^[a-zA-Z0-9][a-zA-Z0-9_./-]*$' -or $c.branch.Contains('..')){throw 'Invalid branch'}
 }else{
  if($c.project -cnotmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]*$'){throw 'Invalid project'}
  if($c.account -and $c.account -cnotmatch '^[a-fA-F0-9]{32}$'){throw 'Invalid account'}
 }
 Write-Host "Provider: $key | Other providers are preserved"
 $reply=Ask 'Save this provider? (y/N)' 'N'
 if($reply -notmatch '^[yYsS]'){Write-Host 'Configuration unchanged';return}
 $path=Get-ZetaProviderPath $name $key
 [void](New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force)
 $lines=[Collections.Generic.List[string]]::new()
 foreach($field in @('provider','repository','branch','project','account')){$lines.Add(('{0}={1}' -f $field,$c[$field]))}
 $tmp="$path.tmp"
 try{
  [IO.File]::WriteAllText($tmp,($lines -join [Environment]::NewLine),[Text.UTF8Encoding]::new($false))
  Move-Item -LiteralPath $tmp -Destination $path -Force
 }finally{if(Test-Path -LiteralPath $tmp){Remove-Item -LiteralPath $tmp -Force}}
 Write-Host "Saved provider $key. Use: .\zeta.ps1 deploy $name" -ForegroundColor Green
}
function Show-ZetaDeploy([string]$name){
 $providers=@(Get-ZetaProviders $name)
 if(!$providers.Count){Write-Host 'No deployment provider configured';return}
 Write-Host "Site: $name | $($providers.Count) provider(s)"
 foreach($provider in $providers){
  $c=Read-ZetaProvider $name $provider
  if($provider -eq 'github-pages'){Write-Host "  GitHub Pages: $($c.repository) ($($c.branch))"}
  else{Write-Host "  Cloudflare Pages: $($c.project)"}
 }
}
function Get-ZetaProviderPath([string]$name,[string]$provider){
 if($provider -notin @('github-pages','cloudflare-pages')){throw 'Invalid provider'}
 Join-Path (SiteDir $name) "deploy/$provider.conf"
}
function Get-ZetaProviders([string]$name){
 [void](ConfigPath $name)
 $all=[Collections.Generic.List[string]]::new()
 foreach($provider in @('github-pages','cloudflare-pages')){
  $new=Get-ZetaProviderPath $name $provider
  if(Test-Path -LiteralPath $new -PathType Leaf){$all.Add($provider);continue}
  $old=Join-Path (SiteDir $name) 'deploy.conf'
  if(Test-Path -LiteralPath $old -PathType Leaf){
   $value=Read-ZetaConfigFile $old
   if($value.provider -eq $provider){$all.Add($provider)}
  }
 }
 return $all.ToArray()
}
function Read-ZetaConfigFile([string]$path){
 if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw "No deploy destination at $path"}
 if((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Symlinked deploy config denied'}
 $c=@{}
 foreach($line in [IO.File]::ReadAllLines($path)){
  if($line -match '^([a-z]+)=(.*)$'){$c[$Matches[1]]=$Matches[2]}
  elseif($line.Trim()){throw "Malformed deploy configuration: $path"}
 }
 return $c
}
function Read-ZetaProvider([string]$name,[string]$provider){
 $path=Get-ZetaProviderPath $name $provider
 if(!(Test-Path -LiteralPath $path)){
  $path=Join-Path (SiteDir $name) 'deploy.conf'
 }
 $c=Read-ZetaConfigFile $path
 if($c.provider -ne $provider){throw "Provider $provider not configured"}
 if($provider -eq 'github-pages'){
  if($c.repository -cnotmatch '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$' -or $c.repository.Contains('..')){throw 'Invalid repository'}
  if($c.branch -cnotmatch '^[a-zA-Z0-9][a-zA-Z0-9_./-]*$' -or $c.branch.Contains('..')){throw 'Invalid branch'}
 }else{
  if($c.project -cnotmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]*$'){throw 'Invalid project'}
  if($c.account -and $c.account -cnotmatch '^[a-fA-F0-9]{32}$'){throw 'Invalid account'}
 }
 return $c
}
function Select-ZetaDeployTargets([string]$name,[string]$choice=''){
 $available=@(Get-ZetaProviders $name)
 if($available.Count -eq 0){throw "No deployment destination. Run: .\zeta.ps1 deploy setup $name"}
 if(!$choice -and $available.Count -gt 1){
  if([Console]::IsInputRedirected){throw 'Multiple targets: specify all or provider explicitly'}
  Write-Host 'Choose deployment targets (all by default):' -ForegroundColor Cyan
  for($i=0;$i -lt $available.Count;$i++){Write-Host ("  [{0}] {1}" -f ($i+1),$available[$i])}
  $choice=Read-Host 'Targets [all / 1,2 / 1]'
 }
 if(!$choice -or $choice -eq 'all'){$selected=$available}
 else{
  $selected=[Collections.Generic.List[string]]::new()
  foreach($token in ($choice -split ',')){
   $provider=$token
   $index=0
   if([int]::TryParse($token,[ref]$index)){
    if($index -lt 1 -or $index -gt $available.Count){throw "Invalid target: $token"}
    $provider=$available[$index-1]
   }
   if($provider -notin $available){throw "Provider not configured: $provider"}
   if($provider -notin $selected){$selected.Add($provider)}
  }
  $selected=@($selected.ToArray())
 }
 if($selected.Count -eq 0){throw 'Select at least one destination'}
 foreach($provider in $selected){$null=Read-ZetaProvider $name $provider}
 return @($selected)
}
function Invoke-ZetaProvider([string]$name,[string]$provider,[string]$dir){
 $c=Read-ZetaProvider $name $provider
 if($provider -eq 'cloudflare-pages'){
  if(!(Get-Command wrangler -ErrorAction SilentlyContinue)){throw 'Install Wrangler and run wrangler login'}
  $original=$env:CLOUDFLARE_ACCOUNT_ID
  try{
   if($c.account){$env:CLOUDFLARE_ACCOUNT_ID=$c.account}
   & wrangler pages deploy $dir --project-name $c.project
   if($LASTEXITCODE -ne 0){throw 'Cloudflare deployment failed'}
  }finally{$env:CLOUDFLARE_ACCOUNT_ID=$original}
  return
 }
 if(!(Get-Command git -ErrorAction SilentlyContinue)){throw 'Git is required'}
 $temp=Join-Path ([IO.Path]::GetTempPath()) ('zeta-deploy-'+[guid]::NewGuid().ToString('N'))
 try{
  & git clone --quiet --depth 1 --branch $c.branch "https://github.com/$($c.repository).git" $temp
  if($LASTEXITCODE -ne 0){throw 'Clone failed; check your publishing branch'}
  Push-Location $temp
  try{
   $tracked=@(& git ls-files)
   if($LASTEXITCODE -ne 0){throw 'Cannot inspect publishing branch'}
   foreach($relative in $tracked){$p=Join-Path $temp $relative;if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p -Force}}
   foreach($item in @(Get-ChildItem -LiteralPath $dir -Force)){Copy-Item -LiteralPath $item.FullName -Destination $temp -Recurse -Force}
   [IO.File]::WriteAllText((Join-Path $temp '.nojekyll'),'')
   & git add -A
   if($LASTEXITCODE -ne 0){throw 'git add failed'}
   & git diff --cached --quiet
   if($LASTEXITCODE -eq 0){Write-Host 'No changes for GitHub Pages';return}
   & git -c user.name='Zeta Deploy' -c user.email='zeta-deploy@users.noreply.github.com' commit -m "Deploy $name"
   if($LASTEXITCODE -ne 0){throw 'Commit failed'}
   & git push origin $c.branch
   if($LASTEXITCODE -ne 0){throw 'Push failed'}
  }finally{Pop-Location}
 }finally{if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}}
}
function Invoke-ZetaDeploy([string]$name,[switch]$DryRun,[string]$Targets=''){
 $cfg=Config $name
 $selected=@(Select-ZetaDeployTargets $name $Targets)
 if(!(SafeDir $cfg.output)){throw 'Unsafe output directory'}
 $dir=Join-Path (SiteDir $name) $cfg.output
 Write-Host "ZETA / Deploy $name" -ForegroundColor Cyan
 Write-Host "Selected targets: $($selected -join ', ')"
 if(-not $DryRun){Build $name;Doctor $name}
 if(!(Test-Path -LiteralPath (Join-Path $dir 'index.html') -PathType Leaf)){throw 'Missing index.html'}
 if((Get-Item -LiteralPath $dir).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Unsafe output directory'}
 $items=@(Get-ChildItem -LiteralPath $dir -Force -Recurse)
 foreach($item in $items){
  if($item.Name -eq '.git' -or $item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Unsafe output: symlink or Git metadata'}
  if(!$item.PSIsContainer -and ($item.Name -in @('config.yaml','deploy.conf','.env') -or $item.Extension -in @('.md','.pem','.key'))){throw "Source/secret in public/: $($item.Name)"}
 }
 if($DryRun){
  Write-Host 'DRY RUN: no remote changes'
  $root=(Resolve-Path -LiteralPath $dir).Path
  foreach($item in $items){if(!$item.PSIsContainer){Write-Host $item.FullName.Substring($root.Length+1)}}
  return
 }
 if(-not [Console]::IsInputRedirected){
  $answer=Read-Host 'Publish to selected targets? (y/N)'
  if($answer -notmatch '^[yYsS]'){Write-Host 'Cancelled';return}
 }
 $success=0;$failed=0
 foreach($provider in $selected){
  try{
   Write-Host "Publishing to $provider..." -ForegroundColor Cyan
   Invoke-ZetaProvider $name $provider $dir
   $success++
   Write-Host "[OK] $provider" -ForegroundColor Green
  }catch{
   $failed++
   Write-Host "[ERROR] $provider : $($_.Exception.Message)" -ForegroundColor Red
  }
 }
 Write-Host ("Deployment summary: {0} succeeded, {1} failed" -f $success,$failed)
 if($failed){throw 'At least one provider failed'}
}
function ZetaDeploy([string]$name,[string]$action='',[string]$targets=''){
 if($name -in @('setup','configure','status','dry-run','assistant','menu')){
  $mode=$name;$name=$action;$action=$mode
 }
 if(!$name){$name=SelectItem 'Site' @(SiteNames)}
 switch($action){
  'setup'{Setup-ZetaDeploy $name}
  'configure'{Setup-ZetaDeploy $name}
  'status'{Show-ZetaDeploy $name}
  'dry-run'{Invoke-ZetaDeploy $name -DryRun -Targets $targets}
  'assistant'{Show-ZetaDeployMenu $name}
  'menu'{Show-ZetaDeployMenu $name}
  ''{Invoke-ZetaDeploy $name -Targets $targets}
  default{throw "Unknown deploy action: $action"}
 }
}
