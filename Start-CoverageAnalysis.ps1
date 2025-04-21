#!/usr/bin/env pwsh

using module ./src/modules/SentinelAnalyzer.psm1

#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Az.Accounts'; ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='Az.SecurityInsights'; ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='Az.OperationalInsights'; ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='PSGraph'; ModuleVersion='2.1.38' }

[CmdletBinding()]
param()

# Import modules
Import-Module "$PSScriptRoot/src/modules/SentinelAnalyzer.psm1"
Import-Module "$PSScriptRoot/src/modules/Visualization.psm1"
Import-Module "$PSScriptRoot/src/modules/Reporting.psm1"
Import-Module "$PSScriptRoot/src/modules/AutomationAnalyzer.psm1"

# Start transcript logging
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $PSScriptRoot "logs/coverage-analysis-$timestamp.log"
$null = New-Item -ItemType Directory -Path (Split-Path $logFile -Parent) -Force
Start-Transcript -Path $logFile

try {
    Write-Host "Loading configuration..."
    $configPath = Join-Path $PSScriptRoot "config.json"
    $config = Get-Content $configPath | ConvertFrom-Json
    
    Write-Host "Using workspace ID from config: $($config.azure.workspaceId)"
    
    Write-Host "Connecting to Azure..."
    Connect-AzAccount -Tenant $config.azure.tenantId -Subscription $config.azure.subscriptionId
    
    Write-Host "Getting Sentinel rules..."
    $rules = Get-SentinelRules -Config $config
    
    Write-Host "Getting tables used by rules..."
    # Get tables from each rule's query
    $tables = @{}
    foreach ($rule in $rules) {
        if ($rule.Query) {
            Write-Verbose "Processing query for rule: $($rule.DisplayName)"
            $ruleTables = Get-KQLTables -Query $rule.Query -Config $config
            foreach ($table in $ruleTables.Keys) {
                if (-not $tables.ContainsKey($table)) {
                    $tables[$table] = $ruleTables[$table]
                }
            }
        }
    }
    
    Write-Host "Getting automation rules and mappings..."
    $automationRules = Get-AutomationRules -SubscriptionId $config.azure.subscriptionId -ResourceGroup $config.azure.resourceGroup -WorkspaceName $config.azure.workspaceName
    
    Write-Host "Analyzing rules and their data sources..."
    $analysisResults = @{
        Rules = $rules
        Tables = $tables
        AutomationRules = $automationRules
    }
    
    Write-Host "Generating visualizations..."
    $outputPath = $config.output.path
    $null = New-Item -ItemType Directory -Path $outputPath -Force
    Write-Verbose "Using output path: $outputPath"
    
    Write-Host "Creating network graph..."
    $networkGraph = New-NetworkGraph -RuleData $analysisResults -Config $config
    
    Write-Host "Creating coverage heatmap..."
    $heatmap = New-CoverageHeatmap -CoverageData $analysisResults -Config $config
    
    Write-Host "Generating reports..."
    $reports = Export-CoverageReport -AnalysisResults $analysisResults -Config $config
    Write-Host "Coverage reports created:"
    Write-Host "  HTML Report: $($reports.HtmlReport)"
    Write-Host "  Excel Report: $($reports.ExcelReport)"
    
    # Display summary
    $activeRules = $rules | Where-Object { $_.Enabled }
    $activeTables = $tables.GetEnumerator() | Where-Object { $_.Value }
    $staleTables = $tables.GetEnumerator() | Where-Object { -not $_.Value }
    $activeAutomationRules = $automationRules | Where-Object { $_.Enabled }
    
    Write-Host "`nAnalysis Summary:"
    Write-Host "Total Rules: $($rules.Count)"
    Write-Host "Active Rules: $($activeRules.Count)"
    Write-Host "Tables Used: $($tables.Count)"
    Write-Host "Active Tables: $($activeTables.Count)"
    Write-Host "Stale Tables: $($staleTables.Count)"
    Write-Host "Automation Rules: $($automationRules.Count)"
    Write-Host "Active Automation Rules: $($activeAutomationRules.Count)"
    
    Write-Host "`nAnalysis completed successfully!"
}
catch {
    Write-Error "Analysis failed: $($_.Exception.Message)"
    Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
    throw
}
finally {
    Stop-Transcript
} 