#!/usr/bin/env pwsh

#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Az.Accounts'; ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='Az.SecurityInsights'; ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='Az.OperationalInsights'; ModuleVersion='2.0.0' }

using module ./SentinelAnalyzer.psm1

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "config.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipVisualization,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipReports
)

# Initialize logging
$logPath = "logs"
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath | Out-Null
}
Start-Transcript -Path "$logPath/coverage-analysis-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

try {
    Write-Host "Loading configuration..." -ForegroundColor Cyan
    $config = Import-AnalyzerConfig -ConfigPath $ConfigPath
    
    Write-Host "Connecting to Azure..." -ForegroundColor Cyan
    Connect-ToAzure -Config $config
    
    Write-Host "Retrieving Sentinel rules..." -ForegroundColor Cyan
    $rules = Get-SentinelRules -Config $config
    Write-Host "Found $($rules.Count) rules" -ForegroundColor Green
    
    $analysisResults = @{
        Rules = @()
        Tables = @{}
        Coverage = @{
            TotalRules = $rules.Count
            ActiveRules = 0
            StaleRules = 0
            TotalTables = 0
            ActiveTables = 0
            StaleTables = 0
        }
    }
    
    Write-Host "Analyzing rules and their data sources..." -ForegroundColor Cyan
    foreach ($rule in $rules) {
        $ruleAnalysis = @{
            RuleName = $rule.DisplayName
            RuleId = $rule.Name
            Enabled = $rule.Enabled
            Tables = @()
            StaleDataSources = @()
        }
        
        # Extract tables from KQL query
        $tables = Get-KQLTables -Query $rule.Query
        $ruleAnalysis.Tables = $tables
        
        # Check table activity
        foreach ($table in $tables) {
            if (-not $analysisResults.Tables.ContainsKey($table)) {
                $activity = Test-TableActivity -TableName $table -Config $config
                $analysisResults.Tables[$table] = @{
                    IsActive = $activity.IsActive
                    LastRecord = $activity.LastRecord
                    DaysSinceLastRecord = $activity.DaysSinceLastRecord
                    UsedByRules = @()
                }
                $analysisResults.Coverage.TotalTables++
                if ($activity.IsActive) {
                    $analysisResults.Coverage.ActiveTables++
                }
            }
            
            $analysisResults.Tables[$table].UsedByRules += $rule.DisplayName
            
            if (-not $analysisResults.Tables[$table].IsActive) {
                $ruleAnalysis.StaleDataSources += $table
            }
        }
        
        $analysisResults.Rules += $ruleAnalysis
        
        if ($ruleAnalysis.StaleDataSources.Count -eq 0) {
            $analysisResults.Coverage.ActiveRules++
        } else {
            $analysisResults.Coverage.StaleRules++
        }
        
        Write-Host "Analyzed rule: $($rule.DisplayName)" -ForegroundColor Gray
    }
    
    # Create output directory if it doesn't exist
    $outputPath = $config.reporting.outputPath
    if (-not (Test-Path $outputPath)) {
        New-Item -ItemType Directory -Path $outputPath | Out-Null
    }
    
    # Generate visualizations
    if (-not $SkipVisualization) {
        Write-Host "Generating visualizations..." -ForegroundColor Cyan
        
        if ($config.visualization.networkGraph.enabled) {
            Write-Host "Creating network graph..." -ForegroundColor Gray
            New-NetworkGraph -RuleData $analysisResults -Config $config
        }
        
        if ($config.visualization.heatmap.enabled) {
            Write-Host "Creating coverage heatmap..." -ForegroundColor Gray
            New-CoverageHeatmap -CoverageData $analysisResults -Config $config
        }
    }
    
    # Generate reports
    if (-not $SkipReports) {
        Write-Host "Generating reports..." -ForegroundColor Cyan
        Export-CoverageReport -AnalysisResults $analysisResults -Config $config
    }
    
    # Output summary
    Write-Host "`nAnalysis Summary:" -ForegroundColor Cyan
    Write-Host "Total Rules: $($analysisResults.Coverage.TotalRules)" -ForegroundColor White
    Write-Host "Active Rules: $($analysisResults.Coverage.ActiveRules)" -ForegroundColor Green
    Write-Host "Rules with Stale Data Sources: $($analysisResults.Coverage.StaleRules)" -ForegroundColor Yellow
    Write-Host "Total Data Tables: $($analysisResults.Coverage.TotalTables)" -ForegroundColor White
    Write-Host "Active Tables: $($analysisResults.Coverage.ActiveTables)" -ForegroundColor Green
    Write-Host "Stale Tables: $($($analysisResults.Coverage.TotalTables - $analysisResults.Coverage.ActiveTables))" -ForegroundColor Yellow
    
    Write-Host "`nAnalysis completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Error during analysis: $_" -ForegroundColor Red
    throw $_
}
finally {
    Stop-Transcript
} 