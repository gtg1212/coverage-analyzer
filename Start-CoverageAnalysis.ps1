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
Import-Module "$PSScriptRoot/src/modules/SentinelAnalyzer.psd1" -Force
Import-Module "$PSScriptRoot/src/modules/Visualization.psm1" -Force
Import-Module "$PSScriptRoot/src/modules/Reporting.psm1" -Force

# Start transcript logging
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $PSScriptRoot "logs/coverage-analysis-$timestamp.log"
$null = New-Item -ItemType Directory -Path (Split-Path $logFile -Parent) -Force
Start-Transcript -Path $logFile

try {
    Write-Host "Loading configuration..."
    $config = Import-AnalyzerConfig -ConfigPath "$PSScriptRoot/config.json"
    
    Write-Host "Using workspace ID from config: $($config.azure.workspaceId)"
    
    Write-Host "Connecting to Azure..."
    Connect-ToAzure -Config $config
    
    Write-Host "Retrieving Sentinel rules..."
    $rules = Get-SentinelRules -Config $config
    
    Write-Host "Analyzing rules and their data sources..."
    $ruleData = @{
        Rules = @()
        Tables = @{}
    }
    
    foreach ($rule in $rules) {
        Write-Verbose "Processing rule: $($rule.DisplayName) (Type: $($rule.RuleType))"
        
        # Get tables from KQL query if present
        $tables = @()
        if (-not [string]::IsNullOrWhiteSpace($rule.Query)) {
            $tables = Get-KQLTables -Query $rule.Query
        }
        
        # Add tables to rule object
        $rule | Add-Member -MemberType NoteProperty -Name "Tables" -Value $tables
        
        # Check table activity
        foreach ($table in $tables) {
            if (-not $ruleData.Tables.ContainsKey($table)) {
                $activity = Test-TableActivity -TableName $table -Config $config
                $ruleData.Tables[$table] = $activity
            }
        }
        
        Write-Host "Analyzed rule: $($rule.DisplayName) (Type: $($rule.RuleType))"
        $ruleData.Rules += $rule
    }
    
    Write-Host "Generating visualizations..."
    $outputPath = $config.output.path
    $null = New-Item -ItemType Directory -Path $outputPath -Force
    Write-Verbose "Using output path: $outputPath"
    
    Write-Host "Creating network graph..."
    $networkGraph = New-NetworkGraph -RuleData $ruleData -Config $config
    
    Write-Host "Creating coverage heatmap..."
    $heatmap = New-CoverageHeatmap -CoverageData $ruleData -Config $config
    
    Write-Host "Generating reports..."
    $report = Export-CoverageReport -AnalysisResults $ruleData -Config $config
    Write-Host "Coverage report created: $report"
    
    # Display summary
    $activeRules = $ruleData.Rules | Where-Object { $_.Enabled }
    $activeTables = $ruleData.Tables.Values | Where-Object { $_.IsActive }
    $staleTables = $ruleData.Tables.Values | Where-Object { -not $_.IsActive }
    
    Write-Host "`nAnalysis Summary:"
    Write-Host "Total Rules: $($ruleData.Rules.Count)"
    Write-Host "Active Rules: $($activeRules.Count)"
    Write-Host "Tables Used: $($ruleData.Tables.Count)"
    Write-Host "Active Tables: $($activeTables.Count)"
    Write-Host "Stale Tables: $($staleTables.Count)"
    
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