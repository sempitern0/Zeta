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
 Write-Host "ZETA / Deploy setup: $name" -ForegroundColor Cyan
 $provider=SelectItem 'Provider' @('GitHub Pages','Cloudflare Pages') 'GitHub Pages'
 $c=@{provider='';repository='';branch='';project='';account=''}
 if($provider -eq 'GitHub Pages'){
  $c.provider='github-pages'
  $c.repository=Ask 'GitHub repository (owner/repository)' ''
  $c.branch=Ask 'Publishing branch' 'gh-pages'
 }else{
  $c.provider='cloudflare-pages'
  $c.project=Ask 'Cloudflare Pages project name' ''
  $c.account=Ask 'Cloudflare account ID (optional)' ''
 }
 if($c.provider -eq 'github-pages'){
  if($c.repository -cnotmatch '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$' -or $c.repository.Contains('..')){throw 'Invalid repository'}
  if($c.branch -cnotmatch '^[a-zA-Z0-9][a-zA-Z0-9_./-]*$' -or $c.branch.Contains('..')){throw 'Invalid branch'}
 }else{
  if($c.project -cnotmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]*$'){throw 'Invalid project'}
  if($c.account -and $c.account -cnotmatch '^[a-fA-F0-9]{32}$'){throw 'Invalid account ID'}
 }
 $reply=Ask 'Save this deployment configuration? (y/N)' 'N'
 if($reply -notmatch '^[yYsS]'){Write-Host 'Cancelled';return}
 $path=Get-ZetaDeployFile $name
 $data=(foreach($key in @('provider','repository','branch','project','account')){ "$key=$($c[$key])" }) -join "`n"
 $tmp="$path.tmp"
 try{
  [IO.File]::WriteAllText($tmp,$data,[Text.UTF8Encoding]::new($false))
  Move-Item -LiteralPath $tmp -Destination $path -Force
 }finally{if(Test-Path -LiteralPath $tmp){Remove-Item -LiteralPath $tmp -Force}}
 Write-Host "Saved. Next time use: .\\zeta.ps1 deploy $name" -ForegroundColor Green
}
function Show-ZetaDeploy([string]$name){
 $c=Read-ZetaDeploy $name
 Write-Host "Site: $name | Provider: $($c.provider)"
 if($c.provider -eq 'github-pages'){Write-Host "Repository: $($c.repository) | Branch: $($c.branch)"}
 else{Write-Host "Project: $($c.project)"}
}
function Invoke-ZetaDeploy([string]$name,[switch]$DryRun){
 $cfg=Config $name
 $c=Read-ZetaDeploy $name
 if(!(SafeDir $cfg.output)){throw 'Unsafe output directory'}
 $dir=Join-Path (SiteDir $name) $cfg.output
 if(-not $DryRun){Build $name;Doctor $name}
 $index=Join-Path $dir 'index.html'
 if(!(Test-Path -LiteralPath $index -PathType Leaf)){throw "Site has no generated index.html: $dir"}
 $root=(Resolve-Path -LiteralPath $dir).Path
 if(Test-Path -LiteralPath (Join-Path $dir '.git')){throw "Output contains .git metadata"}
 if((Get-Item -LiteralPath $dir).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Output directory cannot be a symlink'}
 $items=@(Get-ChildItem -LiteralPath $dir -Force -Recurse)
 foreach($item in $items){
  if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Symlink/reparse point in output: $($item.FullName)"}
  if(!$item.PSIsContainer -and ($item.Name -in @('config.yaml','deploy.conf','.env') -or $item.Extension -eq '.md')){throw "Source/config file found in public: $($item.Name)"}
 }
 Show-ZetaDeploy $name
 if($DryRun){Write-Host 'DRY RUN: no remote changes';$items | Where-Object {-not $_.PSIsContainer} | ForEach-Object { Write-Host $_.FullName.Substring($root.Length+1) };return}
 $reply=Ask 'Publish now? (y/N)' 'N'
 if($reply -notmatch '^[yYsS]'){Write-Host 'Cancelled';return}
 if($c.provider -eq 'cloudflare-pages'){
  if(!(Get-Command wrangler -ErrorAction SilentlyContinue)){throw 'Install Wrangler and run: wrangler login'}
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
  $remote="https://github.com/$($c.repository).git"
  & git clone --quiet --depth 1 --branch $c.branch $remote $temp
  if($LASTEXITCODE -ne 0){throw 'Clone failed. Create the publishing branch and enable GitHub Pages first.'}
  # Remove tracked site files but keep Git metadata. Then replace with generated assets.
  Push-Location $temp
  try{
   $tracked=@(& git ls-files)
   if($LASTEXITCODE -ne 0){throw 'Could not inspect publishing branch'}
   foreach($relative in $tracked){$p=Join-Path $temp $relative;if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p -Force}}
   foreach($item in @(Get-ChildItem -LiteralPath $dir -Force)){Copy-Item -LiteralPath $item.FullName -Destination $temp -Recurse -Force}
   [IO.File]::WriteAllText((Join-Path $temp '.nojekyll'),'')
   & git add -A
   if($LASTEXITCODE -ne 0){throw 'git add failed'}
   & git diff --cached --quiet
   if($LASTEXITCODE -eq 0){Write-Host 'Nothing changed';return}
   & git -c user.name='Zeta Deploy' -c user.email='zeta-deploy@users.noreply.github.com' commit -m "Deploy $name"
   if($LASTEXITCODE -ne 0){throw 'Commit failed'}
   & git push origin $c.branch
   if($LASTEXITCODE -ne 0){throw 'Push failed'}
  }finally{Pop-Location}
 }finally{if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}}
}
function ZetaDeploy([string]$name,[string]$action=''){
 if($name -eq 'setup'){$name=$action;$action='setup'}
 if($name -eq 'status'){$name=$action;$action='status'}
 if($name -eq 'dry-run'){$name=$action;$action='dry-run'}
 if(!$name){$name=SelectItem 'Site' @(SiteNames)}
 switch($action){
  'setup'{Setup-ZetaDeploy $name}
  'status'{Show-ZetaDeploy $name}
  'dry-run'{Invoke-ZetaDeploy $name -DryRun}
  ''{if(!(Test-Path -LiteralPath (Join-Path (SiteDir $name) 'deploy.conf'))){Setup-ZetaDeploy $name}else{Invoke-ZetaDeploy $name}}
  default{throw "Unknown deploy action: $action"}
 }
}
