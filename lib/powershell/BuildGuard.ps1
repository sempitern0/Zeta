# A SHA-256 baseline outside public/ detects edits to generated output.
function Get-ZetaBuildManifest([string]$directory) {
  $lines=[Collections.Generic.List[string]]::new()
  if(-not (Test-Path -LiteralPath $directory -PathType Container)){return @()}
  $root=[IO.Path]::GetFullPath($directory)
  foreach($item in @(Get-ChildItem -LiteralPath $root -File -Recurse -Force)){
    $relative=[IO.Path]::GetRelativePath($root,$item.FullName).Replace('\\','/')
    $hash=if($item.LinkType){"link:$($item.Target -join ',')"}else{(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
    $lines.Add("$hash`t$relative")
  }
  $array=$lines.ToArray()
  [Array]::Sort($array,[StringComparer]::Ordinal)
  return ,$array
}
function Assert-ZetaBuildOutputSafe([string]$directory,[string]$manifest,[string]$name,[bool]$force=$false) {
  if(-not (Test-Path -LiteralPath $directory)){return}
  $entry=Get-Item -LiteralPath $directory -Force
  if(-not $entry.PSIsContainer -or $entry.LinkType){throw "Build destination is not a regular directory: $directory"}
  $actual=@(Get-ZetaBuildManifest $directory)
  $baseline=@()
  if(Test-Path -LiteralPath $manifest -PathType Leaf){$baseline=@([IO.File]::ReadAllLines($manifest))}
  elseif($actual.Count -eq 0){return}
  if((Test-Path -LiteralPath $manifest -PathType Leaf) -and
     (($actual -join "`n") -ceq ($baseline -join "`n"))){return}
  if($force){
    Write-Warning "Replacing modified/untracked output for '$name' (-Force)."
    return
  }
  Write-Warning "Untracked or manually changed files detected in '$directory'."
  Write-Warning "Move permanent customizations to sites/$name/styles/ or assets/."
  $isInteractive=$false
  try{$isInteractive=([Environment]::UserInteractive -and -not [Console]::IsInputRedirected)}catch{}
  if($isInteractive){
    $answer=Read-Host "Replace this output and discard its local changes? [y/N]"
    if($answer -in @('y','Y','yes','YES')){return}
  }
  throw "Build canceled: existing output preserved. Use -Force to replace it."
}
