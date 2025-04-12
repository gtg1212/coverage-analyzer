BeforeAll {
    Import-Module "$PSScriptRoot/../src/modules/SentinelAnalyzer.psm1" -Force
}

Describe "Get-KQLTables" {
    It "Should return empty array for empty query" {
        $result = Get-KQLTables -Query ""
        $result | Should -BeOfType [Array]
        $result.Count | Should -Be 0
    }

    It "Should identify single table in simple query" {
        $query = "AuditLogs | where TimeGenerated > ago(1d)"
        $result = Get-KQLTables -Query $query
        $result | Should -Contain "AuditLogs"
        $result.Count | Should -Be 1
    }

    It "Should identify multiple tables in union query" {
        $query = @"
        union AuditLogs, AzureActivity
        | where TimeGenerated > ago(1d)
"@
        $result = Get-KQLTables -Query $query
        $result | Should -Contain "AuditLogs"
        $result | Should -Contain "AzureActivity"
        $result.Count | Should -Be 2
    }

    It "Should identify tables in join query" {
        $query = @"
        AuditLogs
        | join kind=inner (
            AzureActivity
            | where OperationName has "role"
        ) on $"Identity"
"@
        $result = Get-KQLTables -Query $query
        $result | Should -Contain "AuditLogs"
        $result | Should -Contain "AzureActivity"
        $result.Count | Should -Be 2
    }
}

Describe "Import-AnalyzerConfig" {
    It "Should throw on invalid config path" {
        { Import-AnalyzerConfig -ConfigPath "nonexistent.json" } | Should -Throw
    }

    It "Should load valid config file" {
        $configPath = "config.example.json"
        $config = Import-AnalyzerConfig -ConfigPath $configPath
        $config | Should -Not -BeNullOrEmpty
        $config.azure | Should -Not -BeNullOrEmpty
        $config.azure.tenantId | Should -Not -BeNullOrEmpty
        $config.analysis.stalenessThresholds | Should -Not -BeNullOrEmpty
    }
} 