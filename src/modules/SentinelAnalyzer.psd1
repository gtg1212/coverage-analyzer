@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'SentinelAnalyzer.psm1'
    
    # Version number of this module.
    ModuleVersion = '1.0.0'
    
    # ID used to uniquely identify this module
    GUID = '12345678-1234-1234-1234-123456789012'
    
    # Author of this module
    Author = 'Your Name'
    
    # Company or vendor of this module
    CompanyName = 'Unknown'
    
    # Copyright statement for this module
    Copyright = '(c) 2024. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Analyzes Microsoft Sentinel rule coverage and data source activity'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'
    
    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.12.1' },
        @{ ModuleName = 'Az.SecurityInsights'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Az.OperationalInsights'; ModuleVersion = '3.1.0' },
        @{ ModuleName = 'PSGraph'; ModuleVersion = '2.1.38' }
    )
    
    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    ScriptsToProcess = @()
    
    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()
    
    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @()
    
    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @(
        'Visualization.psm1',
        'Reporting.psm1'
    )
    
    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        # Core functions
        'Import-AnalyzerConfig',
        'Connect-ToAzure',
        'Get-WorkspaceId',
        'Get-SentinelRules',
        'Get-KQLTables',
        'Test-TableActivity',
        # Visualization functions
        'New-NetworkGraph',
        'New-CoverageHeatmap',
        # Reporting functions
        'Export-CoverageReport'
    )
    
    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = '*'
    
    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('Azure', 'Sentinel', 'Security', 'Analysis')
            
            # License URI for this module
            LicenseUri = 'https://github.com/yourusername/coverage-analyzer/blob/main/LICENSE'
            
            # Project URI for this module
            ProjectUri = 'https://github.com/yourusername/coverage-analyzer'
            
            # Release notes for this module
            ReleaseNotes = 'Initial release'
        }
    }
} 