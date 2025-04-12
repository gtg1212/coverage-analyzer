# Reporting functions
function Export-CoverageReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSObject]$AnalysisResults,
        [Parameter(Mandatory=$true)]
        [PSObject]$Config
    )
    
    try {
        Write-Verbose "Generating coverage report..."
        
        # Create output directory if it doesn't exist
        if (-not (Test-Path $Config.output.path)) {
            Write-Verbose "Creating output directory: $($Config.output.path)"
            $null = New-Item -ItemType Directory -Path $Config.output.path -Force
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Calculate summary statistics
        $activeRules = $AnalysisResults.Rules | Where-Object { $_.Enabled }
        $activeTables = $AnalysisResults.Tables.Values | Where-Object { $_ -eq $true }
        
        # Generate HTML content
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Sentinel Coverage Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1, h2, h3 { color: #333; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .summary { margin-bottom: 20px; }
        .warning { color: #ff9900; }
        .error { color: #ff0000; }
        .success { color: #009900; }
    </style>
</head>
<body>
    <h1>Sentinel Coverage Analysis Report</h1>
    <p>Generated on: $timestamp</p>
    
    <div class="summary">
        <h2>Summary</h2>
        <p>Total Rules: $($AnalysisResults.Rules.Count)</p>
        <p>Active Rules: $($activeRules.Count)</p>
        <p>Tables Used: $($AnalysisResults.Tables.Count)</p>
        <p>Active Tables: $($activeTables.Count)</p>
    </div>
    
    <h2>Rules</h2>
    <table>
        <tr>
            <th>Name</th>
            <th>Type</th>
            <th>Status</th>
            <th>Tables</th>
        </tr>
"@
        
        foreach ($rule in $AnalysisResults.Rules) {
            $statusClass = if ($rule.Enabled) { "success" } else { "error" }
            $html += @"
        <tr>
            <td>$($rule.DisplayName)</td>
            <td>$($rule.RuleType)</td>
            <td class="$statusClass">$(if ($rule.Enabled) { "Enabled" } else { "Disabled" })</td>
            <td>$($rule.Tables -join ", ")</td>
        </tr>
"@
        }
        
        $html += @"
    </table>
    
    <h2>Tables</h2>
    <table>
        <tr>
            <th>Name</th>
            <th>Status</th>
            <th>Last Record</th>
            <th>Days Since Last Record</th>
        </tr>
"@
        
        foreach ($table in $AnalysisResults.Tables.Keys) {
            $isActive = $AnalysisResults.Tables[$table]
            $statusClass = if ($isActive) { "success" } else { "error" }
            $html += @"
        <tr>
            <td>$table</td>
            <td class="$statusClass">$(if ($isActive) { "Active" } else { "Inactive" })</td>
            <td>$(if ($isActive) { "Within 7 days" } else { "N/A" })</td>
            <td>$(if ($isActive) { "< 7" } else { "" })</td>
        </tr>
"@
        }
        
        $html += @"
    </table>
</body>
</html>
"@
        
        # Save the report
        $outputPath = Join-Path $Config.output.path "coverage-report.html"
        Write-Verbose "Saving report to: $outputPath"
        $html | Out-File -FilePath $outputPath -Encoding UTF8
        
        return $outputPath
    }
    catch {
        Write-Error "Failed to generate coverage report: $_"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        return $null
    }
}

Export-ModuleMember -Function Export-CoverageReport 