# SentinelAnalyzer.psm1

#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Az.Accounts'; ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='Az.SecurityInsights'; ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='Az.OperationalInsights'; ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='PSGraph'; ModuleVersion='2.1.38' }

# Core functions for Sentinel rule analysis
function Import-AnalyzerConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    try {
        if (-not (Test-Path $ConfigPath)) {
            Write-Error "Configuration file not found at path: $ConfigPath"
            return $null
        }

        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        Write-Verbose "Configuration loaded successfully from $ConfigPath"
        return $config
    }
    catch {
        Write-Error "Failed to import configuration: $_"
        return $null
    }
}

function Connect-ToAzure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Config
    )

    try {
        $context = Get-AzContext
        if ($null -eq $context -or 
            $context.Tenant.Id -ne $Config.azure.tenantId -or 
            $context.Subscription.Id -ne $Config.azure.subscriptionId) {
            
            Write-Verbose "Connecting to Azure..."
            Connect-AzAccount -Tenant $Config.azure.tenantId -Subscription $Config.azure.subscriptionId
            Write-Verbose "Successfully connected to Azure"
        }
        else {
            Write-Verbose "Already connected to correct Azure context"
        }
        return $true
    }
    catch {
        Write-Error "Failed to connect to Azure: $_"
        return $false
    }
}

function Get-WorkspaceId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Config
    )

    try {
        if ($Config.azure.workspaceId) {
            Write-Verbose "Using workspace ID from config: $($Config.azure.workspaceId)"
            return $Config.azure.workspaceId
        }

        Write-Verbose "Retrieving workspace ID from Azure..."
        $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $Config.azure.resourceGroup -Name $Config.azure.workspaceName
        
        if ($null -eq $workspace) {
            Write-Error "Workspace not found: $($Config.azure.workspaceName)"
            return $null
        }

        Write-Verbose "Successfully retrieved workspace ID"
        return $workspace.CustomerId
    }
    catch {
        Write-Error "Failed to get workspace ID: $_"
        return $null
    }
}

function Get-SentinelRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Config
    )

    try {
        Write-Verbose "Retrieving Sentinel rules..."
        $rules = Get-AzSentinelAlertRule -ResourceGroupName $Config.azure.resourceGroup -WorkspaceName $Config.azure.workspaceName

        # Rule type mapping
        $ruleTypes = @{
            'Scheduled' = 'Scheduled Analytics'
            'Fusion' = 'Fusion'
            'MLBehaviorAnalytics' = 'ML Behavior Analytics'
            'MicrosoftSecurityIncidentCreation' = 'Microsoft Security'
            'NRT' = 'Near Real Time'
        }

        $ruleInfo = @()
        foreach ($rule in $rules) {
            Write-Verbose "Processing rule: $($rule.DisplayName)"
            Write-Verbose "Raw rule object properties: $(($rule | Get-Member -MemberType Properties).Name -join ', ')"
            
            # Extract rule type
            $rawKind = $null
            if ($rule.PSObject.Properties.Name -contains 'Kind') {
                $rawKind = $rule.Kind
                Write-Verbose "Found Kind directly: $rawKind"
            }
            elseif ($rule.PSObject.Properties.Name -contains 'Properties' -and 
                   $rule.Properties.PSObject.Properties.Name -contains 'Kind') {
                $rawKind = $rule.Properties.Kind
                Write-Verbose "Found Kind in Properties: $rawKind"
            }

            # Map the raw kind to a friendly type name
            $type = switch -Regex ($rawKind) {
                'Scheduled$' { 'Scheduled Analytics' }
                'Fusion$' { 'Fusion' }
                'MLBehaviorAnalytics$' { 'ML Behavior Analytics' }
                'MicrosoftSecurityIncidentCreation$' { 'Microsoft Security' }
                'NRT$' { 'Near Real Time' }
                default { $rawKind }
            }
            
            Write-Verbose "Mapped rule type: $type"

            # Get query from either direct property or Properties
            $query = if ($rule.PSObject.Properties.Name -contains 'Query') { 
                $rule.Query 
            } elseif ($rule.PSObject.Properties.Name -contains 'Properties' -and 
                      $rule.Properties.PSObject.Properties.Name -contains 'Query') { 
                $rule.Properties.Query 
            }

            # Get enabled status
            $enabled = if ($rule.PSObject.Properties.Name -contains 'Enabled') { 
                $rule.Enabled 
            } elseif ($rule.PSObject.Properties.Name -contains 'Properties' -and 
                      $rule.Properties.PSObject.Properties.Name -contains 'Enabled') { 
                $rule.Properties.Enabled 
            } else {
                # Default to true for Fusion and ML rules
                $type -in @('Fusion', 'ML Behavior Analytics', 'Microsoft Security')
            }

            $ruleInfo += [PSCustomObject]@{
                DisplayName = $rule.DisplayName
                Name = $rule.Name
                Enabled = $enabled
                Query = $query
                RuleType = $type
                RawKind = $rawKind
            }
        }

        # Group and display rule type summary
        $ruleTypeCounts = $ruleInfo | Group-Object -Property RuleType | Select-Object Name, Count
        Write-Verbose "`nRule Types Found:"
        foreach ($typeCount in $ruleTypeCounts) {
            Write-Verbose "- $($typeCount.Name): $($typeCount.Count) rules"
        }
        Write-Verbose "Total Rules Found: $($ruleInfo.Count)"

        return $ruleInfo
    }
    catch {
        Write-Error "Failed to get Sentinel rules: $_"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        return @()
    }
}

function Get-KQLTables {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,
        [Parameter(Mandatory = $true)]
        [PSObject]$Config
    )

    try {
        Write-Verbose "Getting available tables from Log Analytics workspace..."
        
        try {
            # Verify we have the required workspace information
            if ([string]::IsNullOrEmpty($Config.azure.resourceGroup) -or 
                [string]::IsNullOrEmpty($Config.azure.workspaceName) -or 
                [string]::IsNullOrEmpty($Config.azure.subscriptionId)) {
                Write-Error "Missing required workspace information in config"
                return @()
            }

            Write-Verbose "Using workspace: $($Config.azure.workspaceName) in resource group: $($Config.azure.resourceGroup)"
            
            # Get current context and verify subscription
            $context = Get-AzContext
            if ($null -eq $context -or $context.Subscription.Id -ne $Config.azure.subscriptionId) {
                Write-Verbose "Setting Azure context to subscription: $($Config.azure.subscriptionId)"
                $null = Set-AzContext -SubscriptionId $Config.azure.subscriptionId -ErrorAction Stop
            }
            
            # Get tables using Az.OperationalInsights
            Write-Verbose "Retrieving tables from workspace..."
            $tables = Get-AzOperationalInsightsTable `
                -ResourceGroupName $Config.azure.resourceGroup `
                -WorkspaceName $Config.azure.workspaceName `
                -ErrorAction Stop
            
            $availableTables = $tables | ForEach-Object { $_.Name } | Where-Object { $_ -ne $null -and $_ -ne '' }
            
            if ($availableTables.Count -gt 0) {
                Write-Verbose "Found $($availableTables.Count) tables in workspace"
                Write-Verbose "Available tables: $($availableTables -join ', ')"
            } else {
                Write-Warning "No tables found in workspace"
                return @()
            }
        }
        catch {
            Write-Error ("Failed to get tables from workspace: {0}" -f $_.Exception.Message)
            Write-Verbose $_.Exception.StackTrace
            return @()
        }

        Write-Verbose "Extracting table names from KQL query..."
        
        if ($availableTables.Count -eq 0) {
            Write-Warning "No available tables to match against"
            return @()
        }

        # Clean the query by removing comments and extra whitespace
        $cleanQuery = $Query -replace '//.*$', '' -replace '/\*[\s\S]*?\*/', '' -replace '\s+', ' '
        Write-Verbose "Cleaned query: $cleanQuery"

        # Common KQL operators that might follow a table name
        $kqlOperators = @(
            'where', 'project', 'extend', 'summarize', 'take', 'top', 'limit', 'count',
            'distinct', 'parse', 'parse-where', 'evaluate', 'join', 'union', 'let',
            'datatable', 'sort', 'order', 'serialize', 'mv-expand', 'lookup', 'make-series',
            'partition', 'range', 'scan', 'search', 'find', 'autocluster', 'bag_unpack'
        ) -join '|'

        # Create patterns for different KQL contexts
        $patterns = @(
            # Table after let statements (at start of a new line or after semicolon)
            "(?i)(?:^|;\s*)(?:let\s+[^;]+;\s*)*($($availableTables -join '|'))\s*(?:\||$|\s+(?:$kqlOperators)\s)",
            
            # Standard table reference at start or after pipe
            "(?i)(?:^|\|\s*)($($availableTables -join '|'))\s*(?:\||$|\s+(?:$kqlOperators)\s)",
            
            # Table in union/join operations (including optional kind=)
            "(?i)(?:union|join)\s+(?:kind\s*=\s*\w+\s+)?($($availableTables -join '|'))\s*(?:\||$|\s+(?:$kqlOperators)\s|on\s)",
            
            # Table in let statement value
            "(?i)let\s+\w+\s*=\s*($($availableTables -join '|'))\s*(?:\||$|\s+(?:$kqlOperators)\s)",
            
            # Table in materialized view
            "(?i)view\s+\w+\s+as\s+($($availableTables -join '|'))\s*(?:\||$|\s+(?:$kqlOperators)\s)",
            
            # Table in lookup/find operations
            "(?i)(?:lookup|find)\s+in\s+($($availableTables -join '|'))\s*(?:\||$|\s+(?:$kqlOperators)\s|on\s)",
            
            # Table in subqueries
            "(?i)\(\s*($($availableTables -join '|'))\s*(?:\||$|\s+(?:$kqlOperators)\s)",

            # Standalone table reference after semicolon
            "(?i);\s*($($availableTables -join '|'))\s*(?:\||$|\s+(?:$kqlOperators)\s)"
        )

        $foundTables = @()
        foreach ($pattern in $patterns) {
            Write-Verbose "Checking pattern: $pattern"
            $matches = [regex]::Matches($cleanQuery, $pattern)
            foreach ($match in $matches) {
                # Get the captured table name (group 1)
                $tableName = $match.Groups[1].Value
                if ($tableName -and -not $foundTables.Contains($tableName)) {
                    Write-Verbose "Found table '$tableName' at position $($match.Index) using pattern: $pattern"
                    $foundTables += $tableName
                }
            }
        }

        Write-Verbose "Found $($foundTables.Count) unique tables in query: $($foundTables -join ', ')"
        return $foundTables
    }
    catch {
        Write-Error "Failed to extract table names: $_"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        return @()
    }
}

function Test-TableActivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        [Parameter(Mandatory = $true)]
        [PSObject]$Config
    )

    try {
        Write-Verbose "Testing activity for table: $TableName"
        
        # Skip known non-table identifiers
        $nonTableIdentifiers = @('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 
            'TargetResources', 'modifiedProperties', 'targetResources', 'AdditionalDetails')
        
        if ($TableName -in $nonTableIdentifiers) {
            Write-Verbose "Skipping non-table identifier: $TableName"
            return $null
        }

        # First check if the table exists by getting its schema
        Write-Verbose "Checking if table $TableName exists..."
        $schemaQuery = "$TableName | getschema | project ColumnName | take 1"
        try {
            $schemaResult = Invoke-AzOperationalInsightsQuery -WorkspaceId $Config.azure.workspaceId -Query $schemaQuery -ErrorAction Stop
            if ($null -eq $schemaResult -or $schemaResult.Results.Count -eq 0) {
                Write-Verbose "Table $TableName does not exist in the workspace"
                return $false
            }
            Write-Verbose "Table $TableName exists in the workspace"
        }
        catch {
            if ($_.Exception.Message -like "*BadRequest*") {
                Write-Verbose "Table ${TableName} does not exist or is not accessible"
                return $false
            }
            throw
        }

        # Now check for recent data
        Write-Verbose "Checking for recent data in table $TableName..."
        $activityQuery = @"
$TableName
| where TimeGenerated > ago(7d)
| summarize LastRecord = max(TimeGenerated)
"@
        
        try {
            $result = Invoke-AzOperationalInsightsQuery -WorkspaceId $Config.azure.workspaceId -Query $activityQuery -ErrorAction Stop
            
            if ($null -eq $result -or 
                $result.Results.Count -eq 0 -or 
                [string]::IsNullOrEmpty($result.Results[0].LastRecord)) {
                Write-Verbose "No activity found in table $TableName in the last 7 days"
                return $false
            }

            $lastRecord = [datetime]::Parse($result.Results[0].LastRecord)
            $daysSinceLastRecord = ([datetime]::UtcNow - $lastRecord).Days
            
            Write-Verbose "Last record in table ${TableName} was ${daysSinceLastRecord} days ago"
            return $daysSinceLastRecord -lt 7
        }
        catch {
            if ($_.Exception.Message -like "*BadRequest*") {
                Write-Verbose ("Error querying table {0} - BadRequest" -f $TableName)
                return $false
            }
            Write-Error ("Error querying table {0}: {1}" -f $TableName, $_.Exception.Message)
            return $false
        }
    }
    catch {
        Write-Error ("Failed to test table activity for {0}: {1}" -f $TableName, $_.Exception.Message)
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        return $false
    }
}

# Export only the core functions
Export-ModuleMember -Function @(
    'Import-AnalyzerConfig',
    'Connect-ToAzure',
    'Get-WorkspaceId',
    'Get-SentinelRules',
    'Get-KQLTables',
    'Test-TableActivity'
)