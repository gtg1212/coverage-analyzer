# Visualization functions
function New-NetworkGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSObject]$RuleData,
        [Parameter(Mandatory=$true)]
        [PSObject]$Config
    )
    
    try {
        Write-Verbose "Starting network graph creation..."
        
        # Verify Graphviz is installed
        try {
            $null = Get-Command dot -ErrorAction Stop
            Write-Verbose "Graphviz is installed and available"
        }
        catch {
            Write-Error "Graphviz is not installed. Please install it using: sudo apt-get install -y graphviz"
            return $null
        }
        
        # Create output directory if it doesn't exist
        if (-not (Test-Path $Config.output.path)) {
            Write-Verbose "Creating output directory: $($Config.output.path)"
            $null = New-Item -ItemType Directory -Path $Config.output.path -Force
        }
        
        Write-Verbose "Creating DOT file content..."
        # Create DOT file content
        $dotContent = @"
digraph G {
    rankdir=LR;
    node [shape=box, style=filled];
"@
        
        Write-Verbose "Adding nodes for rules..."
        # Add nodes for each rule
        foreach ($rule in $RuleData.Rules) {
            $nodeColor = if ($rule.Enabled) { "lightgreen" } else { "lightcoral" }
            $escapedName = $rule.Name -replace '"', '\"'
            $escapedDisplayName = $rule.DisplayName -replace '"', '\"'
            $dotContent += "    `"$escapedName`" [label=`"$escapedDisplayName`", fillcolor=$nodeColor];`n"
        }
        
        Write-Verbose "Adding nodes for tables..."
        # Add nodes for each table
        foreach ($tableName in $RuleData.Tables.Keys) {
            $isActive = $RuleData.Tables[$tableName]
            $nodeColor = if ($isActive) { "lightblue" } else { "lightgray" }
            $escapedTableName = $tableName -replace '"', '\"'
            $dotContent += "    `"table_$escapedTableName`" [label=`"$escapedTableName`", fillcolor=$nodeColor];`n"
        }
        
        Write-Verbose "Adding edges for rule-table relationships..."
        # Add edges for rule-table relationships
        foreach ($rule in $RuleData.Rules) {
            foreach ($table in $rule.Tables) {
                $escapedRuleName = $rule.Name -replace '"', '\"'
                $escapedTableName = $table -replace '"', '\"'
                $dotContent += "    `"$escapedRuleName`" -> `"table_$escapedTableName`";`n"
            }
        }
        
        $dotContent += "}"
        
        # Save DOT file
        $dotPath = Join-Path $Config.output.path "network-graph.dot"
        Write-Verbose "Saving DOT file to: $dotPath"
        $dotContent | Out-File -FilePath $dotPath -Encoding UTF8
        
        # Generate PNG using Graphviz
        $outputPath = Join-Path $Config.output.path "network-graph.png"
        Write-Verbose "Generating PNG using Graphviz..."
        $process = Start-Process -FilePath "dot" -ArgumentList "-Tpng", "`"$dotPath`"", "-o", "`"$outputPath`"" -NoNewWindow -PassThru -Wait
        
        if ($process.ExitCode -ne 0) {
            Write-Error "Graphviz failed to generate the network graph. Exit code: $($process.ExitCode)"
            return $null
        }
        
        Write-Verbose "Network graph created successfully at: $outputPath"
        return $outputPath
    }
    catch {
        Write-Error "Failed to create network graph: $_"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        return $null
    }
}

function New-CoverageHeatmap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSObject]$CoverageData,
        [Parameter(Mandatory=$true)]
        [PSObject]$Config
    )
    
    try {
        Write-Verbose "Starting coverage heatmap creation..."
        
        # Verify Graphviz is installed
        try {
            $null = Get-Command dot -ErrorAction Stop
            Write-Verbose "Graphviz is installed and available"
        }
        catch {
            Write-Error "Graphviz is not installed. Please install it using: sudo apt-get install -y graphviz"
            return $null
        }
        
        # Create output directory if it doesn't exist
        if (-not (Test-Path $Config.output.path)) {
            Write-Verbose "Creating output directory: $($Config.output.path)"
            $null = New-Item -ItemType Directory -Path $Config.output.path -Force
        }
        
        Write-Verbose "Creating DOT file content..."
        # Create DOT file content
        $dotContent = @"
digraph G {
    rankdir=LR;
    node [shape=box, style=filled];
"@
        
        Write-Verbose "Adding nodes for rule types..."
        # Add nodes for each rule type
        $ruleTypes = $CoverageData.Rules | Group-Object -Property RuleType | Select-Object -ExpandProperty Name
        foreach ($ruleType in $ruleTypes) {
            $escapedRuleType = $ruleType -replace '"', '\"'
            $dotContent += "    `"type_$escapedRuleType`" [label=`"$escapedRuleType`", fillcolor=lightblue];`n"
        }
        
        Write-Verbose "Adding nodes for tables..."
        # Add nodes for each table
        foreach ($tableName in $CoverageData.Tables.Keys) {
            $isActive = $CoverageData.Tables[$tableName]
            $nodeColor = if ($isActive) { "lightgreen" } else { "lightcoral" }
            $escapedTableName = $tableName -replace '"', '\"'
            $dotContent += "    `"table_$escapedTableName`" [label=`"$escapedTableName`", fillcolor=$nodeColor];`n"
        }
        
        Write-Verbose "Adding edges for rule type-table relationships..."
        # Add edges for rule type-table relationships
        foreach ($ruleType in $ruleTypes) {
            $rulesOfType = $CoverageData.Rules | Where-Object { $_.RuleType -eq $ruleType }
            foreach ($rule in $rulesOfType) {
                foreach ($table in $rule.Tables) {
                    $escapedRuleType = $ruleType -replace '"', '\"'
                    $escapedTableName = $table -replace '"', '\"'
                    $dotContent += "    `"type_$escapedRuleType`" -> `"table_$escapedTableName`";`n"
                }
            }
        }
        
        $dotContent += "}"
        
        # Save DOT file
        $dotPath = Join-Path $Config.output.path "coverage-heatmap.dot"
        Write-Verbose "Saving DOT file to: $dotPath"
        $dotContent | Out-File -FilePath $dotPath -Encoding UTF8
        
        # Generate PNG using Graphviz
        $outputPath = Join-Path $Config.output.path "coverage-heatmap.png"
        Write-Verbose "Generating PNG using Graphviz..."
        $process = Start-Process -FilePath "dot" -ArgumentList "-Tpng", "`"$dotPath`"", "-o", "`"$outputPath`"" -NoNewWindow -PassThru -Wait
        
        if ($process.ExitCode -ne 0) {
            Write-Error "Graphviz failed to generate the coverage heatmap. Exit code: $($process.ExitCode)"
            return $null
        }
        
        Write-Verbose "Coverage heatmap created successfully at: $outputPath"
        return $outputPath
    }
    catch {
        Write-Error "Failed to create coverage heatmap: $_"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        return $null
    }
}

Export-ModuleMember -Function New-NetworkGraph, New-CoverageHeatmap 