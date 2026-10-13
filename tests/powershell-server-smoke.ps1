#Requires -Version 7.0
# Locally checks the responsive static HTTP server; no Pandoc or GitHub CI.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$workspace=Join-Path $root 'lib/powershell/Workspace.ps1'
$parseErrors=$null
$null=[Management.Automation.Language.Parser]::ParseFile($workspace,[ref]$null,[ref]$parseErrors)
if($parseErrors.Count){throw ($parseErrors | Out-String)}
$siteRoot=Join-Path ([IO.Path]::GetTempPath()) ('zeta-serve-'+[Guid]::NewGuid().ToString('N'))
$job=$null
$client=$null
$probe=$null
try{
 [void](New-Item -ItemType Directory -Path $siteRoot -Force)
 [IO.File]::WriteAllText((Join-Path $siteRoot 'index.html'),'<html><body>Zeta server smoke</body></html>')
 $portProbe=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
 try{
  $portProbe.Start()
  $port=[int]$portProbe.LocalEndpoint.Port
 }finally{$portProbe.Stop()}
 $job=Start-Job -ArgumentList @($workspace,$siteRoot,$port) -ScriptBlock {
  param($module,$directory,$portNumber)
  $ErrorActionPreference='Stop'
  . $module
  Serve $directory $portNumber
 }
 $client=[Net.Http.HttpClient]::new()
 $client.Timeout=[TimeSpan]::FromMilliseconds(800)
 $result=$null
 for($i=0;$i -lt 40;$i++){
  if($job.State -in @('Failed','Completed','Stopped')){throw "Server job exited early: $($job.State)"}
  try{
   $result=$client.GetStringAsync("http://localhost:$port/").GetAwaiter().GetResult()
   break
  }catch{
   Start-Sleep -Milliseconds 100
  }
 }
 if(!$result -or !$result.Contains('Zeta server smoke')){
  throw 'The local preview server did not serve the test HTML.'
 }
 Stop-Job -Job $job
 if(-not (Wait-Job -Job $job -Timeout 5)){throw 'The server did not stop promptly.'}
 Write-Host '[OK] Server responded and its job stopped.' -ForegroundColor Green
}
finally{
 if($null -ne $client){$client.Dispose()}
 if($null -ne $job){
  if($job.State -notin @('Stopped','Completed','Failed')){Stop-Job -Job $job -ErrorAction SilentlyContinue}
  Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
 }
 if(Test-Path -LiteralPath $siteRoot){Remove-Item -LiteralPath $siteRoot -Recurse -Force}
}
