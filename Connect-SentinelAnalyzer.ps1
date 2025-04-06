#!/usr/bin/env pwsh

#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Az.Accounts'; ModuleVersion='2.0.0' }

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "config.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$UseDeviceCode
)

# Import configuration
try {
    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Failed to load configuration from $ConfigPath. Error: $_"
    exit 1
}

# Validate configuration
if (-not $config.azure.tenantId) {
    Write-Error "Azure Tenant ID is not configured in $ConfigPath"
    exit 1
}

if (-not $config.azure.subscriptionId) {
    Write-Error "Azure Subscription ID is not configured in $ConfigPath"
    exit 1
}

# Check if already connected
$context = Get-AzContext
if ($context -and $context.Tenant.Id -eq $config.azure.tenantId -and $context.Subscription.Id -eq $config.azure.subscriptionId) {
    Write-Host "Already connected to Azure with correct tenant and subscription" -ForegroundColor Green
    exit 0
}

# Connect to Azure
try {
    Write-Host "Connecting to Azure..." -ForegroundColor Cyan
    
    $params = @{
        TenantId = $config.azure.tenantId
        SubscriptionId = $config.azure.subscriptionId
    }
    
    if ($UseDeviceCode) {
        $params['UseDeviceAuthentication'] = $true
    }
    
    Connect-AzAccount @params
    
    Write-Host "Successfully connected to Azure" -ForegroundColor Green
    
    # Verify workspace access
    Write-Host "Verifying workspace access..." -ForegroundColor Cyan
    try {
        Get-AzOperationalInsightsWorkspace -ResourceGroupName $config.azure.resourceGroup -Name $config.azure.workspaceName | Out-Null
        Write-Host "Successfully verified workspace access" -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not verify workspace access. Please check your permissions and workspace configuration."
        Write-Warning "Error: $_"
    }
}
catch {
    Write-Error "Failed to connect to Azure. Error: $_"
    exit 1
} 