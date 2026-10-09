#Requires -Version 7.0
<#
.SYNOPSIS
    Discovers models from an OpenAI-compatible server and registers them in an
    agent framework's config file.
.DESCRIPTION
    Queries <BaseUrl>/models, then merges a provider block for the discovered
    models into the config file of the selected agent harness. Supported
    harnesses: opencode. Comments in existing JSON/JSONC configs are dropped
    when the file is rewritten.
.EXAMPLE
    .\set-agent-models.ps1 -BaseUrl http://192.168.1.111:8000/v1 -Harness opencode
    Registers the models at the vLLM endpoint in the global opencode config.
.EXAMPLE
    .\set-agent-models.ps1 -BaseUrl http://192.168.1.111:8000/v1 -Harness opencode -Scope Project -DefaultModel qwen2.5-coder-32b
    Writes ./opencode.json for the current directory and sets it as default model.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$BaseUrl,

    [Parameter(Mandatory)]
    [string]$Harness,

    [ValidateSet('Global', 'Project')]
    [string]$Scope = 'Global',

    [string]$ConfigPath,

    [string]$ProviderId,

    [string]$ApiKey,

    [string]$DefaultModel,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Update-OpenCodeConfig {
    param(
        [Parameter(Mandatory)]$Root,
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)]$Provider,
        [AllowNull()][string]$Model
    )

    if (-not $Root.PSObject.Properties['$schema']) {
        $rebuilt = [pscustomobject]@{ '$schema' = 'https://opencode.ai/config.json' }
        foreach ($prop in $Root.PSObject.Properties) {
            $rebuilt | Add-Member -Force -MemberType NoteProperty -Name $prop.Name -Value $prop.Value
        }
        $Root = $rebuilt
    }

    if ($Root.PSObject.Properties['provider']) {
        $providers = $Root.provider
    }
    else {
        $providers = [pscustomobject]@{}
        $Root | Add-Member -Force -MemberType NoteProperty -Name 'provider' -Value $providers
    }
    $providers | Add-Member -Force -MemberType NoteProperty -Name $Id -Value $Provider

    if ($Root.PSObject.Properties['disabled_providers']) {
        $kept = @($Root.disabled_providers | Where-Object { $_ -ne $Id })
        $Root | Add-Member -Force -MemberType NoteProperty -Name 'disabled_providers' -Value $kept
    }

    if ($Model) {
        $Root | Add-Member -Force -MemberType NoteProperty -Name 'model' -Value "$Id/$Model"
    }

    $Root
}

function Get-OpenCodeConfigPath {
    if ($ConfigPath) {
        $p = if ([System.IO.Path]::IsPathRooted($ConfigPath)) { $ConfigPath } else { Join-Path (Get-Location) $ConfigPath }
        return [System.IO.Path]::GetFullPath($p)
    }

    $dir = if ($Scope -eq 'Global') {
        $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($env:HOME) { $env:HOME } else { $HOME }
        Join-Path $homeDir '.config\opencode'
    } else { (Get-Location).Path }
    $json = Join-Path $dir 'opencode.json'
    $jsonc = Join-Path $dir 'opencode.jsonc'

    if (Test-Path -LiteralPath $json) { return $json }
    if (Test-Path -LiteralPath $jsonc) {
        Write-Warning "Using '$jsonc'; comments will be stripped on rewrite."
        return $jsonc
    }
    return $json
}

$BaseUrl = $BaseUrl.TrimEnd('/')
try { $uri = [Uri]::new($BaseUrl) } catch { throw "BaseUrl is not a valid URL: $BaseUrl" }
if ($uri.Scheme -notin @('http', 'https')) { throw "BaseUrl scheme must be http or https: $BaseUrl" }

$headers = @{ Accept = 'application/json' }
if ($ApiKey) { $headers['Authorization'] = "Bearer $ApiKey" }

Write-Verbose "GET $BaseUrl/models"
try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/models" -Headers $headers -TimeoutSec 30
}
catch {
    if ($uri.AbsolutePath -in @('', '/')) {
        Write-Verbose "'$BaseUrl/models' failed ($($_.Exception.Message)); retrying with /v1 prefix"
        try {
            $response = Invoke-RestMethod -Uri "$BaseUrl/v1/models" -Headers $headers -TimeoutSec 30
            $BaseUrl = "$BaseUrl/v1"
        }
        catch {
            throw "Failed to query '$BaseUrl/models' and '$BaseUrl/v1/models': $($_.Exception.Message)"
        }
    }
    else {
        throw "Failed to query '$BaseUrl/models': $($_.Exception.Message)"
    }
}

$data = if ($response.PSObject.Properties['data']) { @($response.data) } else { @($response) }
$modelIds = @($data | Where-Object { $_.id } | ForEach-Object { if ($_.id -match 'models--(.+?)[\\/]') { $Matches[1] -replace '^(.+?)(--)(.*)$', '$1/$3' } else { $_.id } }) | Select-Object -Unique
if ($modelIds.Count -eq 0) { throw "No models found at '$BaseUrl/models'." }

Write-Host "Discovered $($modelIds.Count) model(s) at $BaseUrl"
$modelIds | ForEach-Object { Write-Host "  - $_" }

if ($DefaultModel -and ($DefaultModel -match 'models--(.+?)[\\/]')) { $DefaultModel = $Matches[1] -replace '^(.+?)(--)(.*)$', '$1/$3' }
if ($DefaultModel -and ($DefaultModel -notin $modelIds)) {
    throw "DefaultModel '$DefaultModel' is not served by $BaseUrl. Available: $($modelIds -join ', ')"
}

if (-not $ProviderId) {
    $ProviderId = 'local-' + (($uri.Host -replace '[.:]+', '-').Trim('-').ToLower())
}

$models = [pscustomobject]@{}
foreach ($id in $modelIds) {
    $models | Add-Member -Force -MemberType NoteProperty -Name $id -Value ([pscustomobject]@{ name = $id })
}

$options = [pscustomobject]@{ baseURL = $BaseUrl }
if ($ApiKey) { $options | Add-Member -Force -MemberType NoteProperty -Name 'apiKey' -Value $ApiKey }

$provider = [pscustomobject]@{}
$provider | Add-Member -Force -MemberType NoteProperty -Name 'npm' -Value '@ai-sdk/openai-compatible'
$provider | Add-Member -Force -MemberType NoteProperty -Name 'name' -Value "OpenAI Compatible ($($uri.Host))"
$provider | Add-Member -Force -MemberType NoteProperty -Name 'options' -Value $options
$provider | Add-Member -Force -MemberType NoteProperty -Name 'models' -Value $models

switch ($Harness.ToLower()) {
    'opencode' {
        $target = Get-OpenCodeConfigPath
        if (Test-Path -LiteralPath $target) {
            $raw = Get-Content -LiteralPath $target -Raw
            try { $config = $raw | ConvertFrom-Json } catch { throw "Existing config '$target' could not be parsed: $($_.Exception.Message)" }
        }
        else {
            $config = [pscustomobject]@{}
        }
        $config = Update-OpenCodeConfig -Root $config -Id $ProviderId -Provider $provider -Model $DefaultModel
        break
    }
    default {
        throw "Unsupported harness '$Harness'. Currently supported: opencode"
    }
}

$output = $config | ConvertTo-Json -Depth 100

if ($DryRun) {
    Write-Host "`n--- would write to $target ---"
    Write-Host $output
    return
}

$parent = Split-Path -LiteralPath $target
if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}
if (Test-Path -LiteralPath $target) {
    Copy-Item -LiteralPath $target -Destination "$target.bak" -Force
    Write-Host "Backup of previous config saved to $target.bak"
}
Set-Content -LiteralPath $target -Value $output -Encoding utf8NoBOM
Write-Host "Updated provider '$ProviderId' ($($modelIds.Count) models) in $target"
Write-Host 'Restart the harness to pick up the new config.'
