# Ensure the folder containing this script is in the module path
if (-not ($env:PSModulePath -like "*$PSScriptRoot*")) {
    $env:PSModulePath += ";$PSScriptRoot"
}

Import-Module jacky-utils
