#Requires -Version 7.0
# No provider access: ensure deploy publishes and setup is an explicit action.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'lib/powershell/Deploy.ps1')
$script:actions=[Collections.Generic.List[string]]::new()
function Invoke-ZetaDeploy([string]$name,[switch]$DryRun,[string]$Targets='') {
 $script:actions.Add(("publish:{0}:{1}:{2}" -f $name,$DryRun.IsPresent,$Targets))
}
function Setup-ZetaDeploy([string]$name) { $script:actions.Add("setup:$name") }
function Show-ZetaDeploy([string]$name) { $script:actions.Add("status:$name") }
function Show-ZetaDeployMenu([string]$name) { $script:actions.Add("assistant:$name") }
ZetaDeploy 'example'
ZetaDeploy 'setup' 'example'
ZetaDeploy 'status' 'example'
ZetaDeploy 'dry-run' 'example'
ZetaDeploy 'assistant' 'example'
ZetaDeploy 'example' '' 'all'
ZetaDeploy 'example' '' 'cloudflare-pages'
$expected=@('publish:example:False:','setup:example','status:example','publish:example:True:','assistant:example','publish:example:False:all','publish:example:False:cloudflare-pages')
if((@($script:actions) -join '|') -cne ($expected -join '|')){
 throw "Deployment command routing diverged: $($script:actions -join ', ')"
}
Write-Host '[OK] PowerShell deploy commands preserve explicit setup/publish separation'
