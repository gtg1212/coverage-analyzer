#!/usr/bin/env pwsh

#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Az.Accounts'; ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='Az.SecurityInsights'; ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='Az.OperationalInsights'; ModuleVersion='2.0.0' }
#Requires -Modules PSGraph

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
$logDir = "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $logDir "coverage-analysis-$timestamp.log"
Start-Transcript -Path $logFile

try {
    Write-Host "Loading configuration..." -ForegroundColor Cyan
    $config = Import-AnalyzerConfig -ConfigPath $ConfigPath
    
    # Check if workspace ID is already in config
    if ([string]::IsNullOrWhiteSpace($config.azure.workspaceId)) {
        Write-Host "Workspace ID not found in config, attempting to retrieve..." -ForegroundColor Yellow
        $workspaceId = Get-WorkspaceId -Config $config
        if ([string]::IsNullOrWhiteSpace($workspaceId)) {
            Write-Warning "Could not retrieve workspace ID. Some functionality may be limited."
        } else {
            Write-Host "Retrieved workspace ID: $workspaceId" -ForegroundColor Green
            $config.azure.workspaceId = $workspaceId
        }
    } else {
        Write-Host "Using workspace ID from config: $($config.azure.workspaceId)" -ForegroundColor Green
    }
    
    Write-Host "Connecting to Azure..." -ForegroundColor Cyan
    Connect-ToAzure -Config $config
    
    Write-Host "Retrieving Sentinel rules..." -ForegroundColor Cyan
    $rules = Get-SentinelRules -Config $config -Verbose
    
    # Group rules by type and display summary
    $rulesByType = $rules | Group-Object -Property RuleType
    Write-Host "`nRule Types Found:" -ForegroundColor Cyan
    foreach ($ruleType in $rulesByType) {
        Write-Host "- $($ruleType.Name): $($ruleType.Count) rules" -ForegroundColor Yellow
    }
    Write-Host "`nTotal Rules Found: $($rules.Count)" -ForegroundColor Green
    
    $analysisResults = @{
        Rules = @()
        Tables = @{}
    }
    
    Write-Host "`nAnalyzing rules and their data sources..." -ForegroundColor Cyan
    foreach ($rule in $rules) {
        Write-Verbose "Processing rule: $($rule.DisplayName) (Type: $($rule.RuleType))"
        
        $ruleAnalysis = @{
            DisplayName = $rule.DisplayName
            Name = $rule.Name
            Enabled = $rule.Enabled
            RuleType = $rule.RuleType
            Tables = @()
            TableActivity = @{}
        }
        
        if ([string]::IsNullOrWhiteSpace($rule.Query)) {
            Write-Warning "Rule '$($rule.DisplayName)' (Type: $($rule.RuleType)) has no query defined"
        } else {
            $tables = Get-KQLTables -Query $rule.Query
            $ruleAnalysis.Tables = $tables
            
            foreach ($table in $tables) {
                $activity = Test-TableActivity -TableName $table -Config $config
                if ($activity) {
                    $ruleAnalysis.TableActivity[$table] = $activity
                    
                    # Add to global table tracking
                    if (-not $analysisResults.Tables.ContainsKey($table)) {
                        $analysisResults.Tables[$table] = $activity
                    }
                } else {
                    Write-Warning "Could not determine activity for table '$table' in rule '$($rule.DisplayName)'"
                }
            }
        }
        
        $analysisResults.Rules += $ruleAnalysis
        Write-Host "Analyzed rule: $($rule.DisplayName) (Type: $($rule.RuleType))" -ForegroundColor Gray
    }
    
    # Create output directory if it doesn't exist
    # Check if output path exists in config, otherwise use default
    $outputPath = "output"
    if ($config.output -and $config.output.path) {
        $outputPath = $config.output.path
    } elseif ($config.reporting -and $config.reporting.outputPath) {
        $outputPath = $config.reporting.outputPath
    }
    
    Write-Verbose "Using output path: $outputPath"
    
    if (-not (Test-Path $outputPath)) {
        Write-Verbose "Creating output directory: $outputPath"
        New-Item -ItemType Directory -Path $outputPath | Out-Null
    }
    
    # Generate visualizations
    if (-not $SkipVisualization) {
        Write-Host "Generating visualizations..." -ForegroundColor Cyan
        
        # Check if PSGraph module is available
        if (-not (Get-Module -ListAvailable -Name PSGraph)) {
            Write-Warning "PSGraph module is not installed. Network graph generation will be skipped. Install with: Install-Module -Name PSGraph -Force"
        }
        else {
            Write-Host "Creating network graph..." -ForegroundColor Gray
            try {
                $networkGraphPath = New-NetworkGraph -RuleData $analysisResults -Config $config
                if ($networkGraphPath) {
                    Write-Host "Network graph created: $networkGraphPath"
                }
            }
            catch {
                Write-Warning "Failed to create network graph: $($_.Exception.Message)"
            }
            
            Write-Host "Creating coverage heatmap..." -ForegroundColor Gray
            try {
                $heatmapPath = New-CoverageHeatmap -CoverageData $analysisResults -Config $config
                if ($heatmapPath) {
                    Write-Host "Coverage heatmap created: $heatmapPath"
                }
            }
            catch {
                Write-Warning "Failed to create coverage heatmap: $($_.Exception.Message)"
            }
        }
    }
    
    # Generate reports
    if (-not $SkipReports) {
        Write-Host "Generating reports..." -ForegroundColor Cyan
        try {
            $reportPath = Export-CoverageReport -AnalysisResults $analysisResults -Config $config
            if ($reportPath) {
                Write-Host "Coverage report created: $reportPath"
            }
        }
        catch {
            Write-Warning "Failed to generate coverage report: $($_.Exception.Message)"
        }
    }
    
    # Output summary
    Write-Host "`nAnalysis Summary:" -ForegroundColor Cyan
    $activeRules = $analysisResults.Rules | Where-Object { $_.Enabled } | Measure-Object | Select-Object -ExpandProperty Count
    $activeTables = $analysisResults.Tables.Values | Where-Object { $_.IsActive } | Measure-Object | Select-Object -ExpandProperty Count
    $staleTables = $analysisResults.Tables.Values | Where-Object { -not $_.IsActive } | Measure-Object | Select-Object -ExpandProperty Count
    
    Write-Host "Total Rules: $($analysisResults.Rules.Count)"
    Write-Host "Active Rules: $activeRules"
    Write-Host "Tables Used: $($analysisResults.Tables.Count)"
    Write-Host "Active Tables: $activeTables"
    Write-Host "Stale Tables: $staleTables"
    
    Write-Host "`nAnalysis completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Error during analysis: $($_.Exception.Message)" -ForegroundColor Red
    Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
    throw $_
}
finally {
    Stop-Transcript
} 