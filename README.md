# Sentinel Coverage Analyzer

A comprehensive tool for analyzing Microsoft Sentinel rules and their data source dependencies.

## Overview

This tool analyzes Microsoft Sentinel analytics rules to:
- Identify which data tables are utilized by each rule
- Check if data tables are actively receiving logs
- Flag rules that depend on stale data sources
- Generate comprehensive coverage reports
- Visualize relationships between rules and data sources

## Prerequisites

- PowerShell 7.0 or higher
- Azure PowerShell modules:
  - Az.Accounts
  - Az.SecurityInsights
  - Az.OperationalInsights
- Required PowerShell visualization modules:
  - PSGraph
  - ImportExcel (for reporting)

## Installation

1. Clone this repository
2. Install required PowerShell modules:
```powershell
Install-Module -Name Az.Accounts -Force
Install-Module -Name Az.SecurityInsights -Force
Install-Module -Name Az.OperationalInsights -Force
Install-Module -Name PSGraph -Force
Install-Module -Name ImportExcel -Force
```

3. Copy `config.template.json` to `config.json` and update with your settings

## Configuration

Edit `config.json` with your specific settings:
- Azure Tenant ID
- Subscription ID
- Resource Group
- Workspace Name
- Staleness thresholds
- Output preferences

## Usage

1. Connect to Azure:
```powershell
.\Connect-SentinelAnalyzer.ps1
```

2. Run the analysis:
```powershell
.\Start-CoverageAnalysis.ps1
```

3. View reports in the `output` directory

## Features

### Rule Analysis
- Extracts and parses KQL queries from all active Sentinel rules
- Identifies referenced data tables
- Maps dependencies between rules and data sources

### Data Source Activity Monitoring
- Checks for active data ingestion
- Flags stale data sources based on configurable thresholds
- Calculates usage metrics

### Reporting
- Generates detailed CSV/HTML reports
- Creates interactive visualizations
- Exports Power BI templates
- Produces network graphs of rule dependencies

### Visualizations
- Interactive network diagrams
- Heat maps of data source coverage
- Dependency graphs
- Power BI dashboards

## Output

The tool generates several types of outputs in the `output` directory:
- Detailed CSV reports
- Interactive HTML visualizations
- Network graphs (PNG/SVG)
- Power BI template files
- Excel workbooks with coverage metrics

## Contributing

Contributions are welcome! Please submit pull requests for any enhancements.

## License

MIT License - See LICENSE file for details 