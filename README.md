# Sentinel Coverage Analyzer

A PowerShell-based tool for analyzing Microsoft Sentinel analytics rules coverage and data source activity.

## Features

- Retrieves and analyzes all types of Sentinel analytics rules
- Checks data source activity and staleness
- Generates visual representations of rule coverage
- Creates detailed HTML reports
- Supports visualization of relationships between rules and data sources

## Prerequisites

- PowerShell 7.0 or later
- Azure PowerShell modules:
  - Az.Accounts (2.0.0 or later)
  - Az.SecurityInsights (2.0.0 or later)
  - Az.OperationalInsights (2.0.0 or later)
- Graphviz (for visualization)
- Required system libraries:
  - libgdiplus
  - libc6-dev

## Installation

1. Clone the repository:
```powershell
git clone https://github.com/gtg1212/coverage-analyzer
cd sentinel-coverage-analyzer
```

2. Install dependencies:
```powershell
./install-dependencies.ps1
```

3. Configure your environment:
```powershell
Copy-Item config.example.json config.json
# Edit config.json with your Azure environment details
```

## Configuration

The `config.json` file contains all necessary settings:

```json
{
  "azure": {
    "tenantId": "your-tenant-id",
    "subscriptionId": "your-subscription-id",
    "resourceGroup": "your-resource-group",
    "workspaceName": "your-workspace-name",
    "workspaceId": null
  },
  "analysis": {
    "stalenessThresholds": {
      "warning": 7,
      "critical": 30
    }
  },
  "output": {
    "path": "output"
  }
}
```

## Usage

Run the analysis:
```powershell
./Start-CoverageAnalysis.ps1
```

The script will:
1. Connect to your Azure environment
2. Retrieve all Sentinel analytics rules
3. Check data source activity
4. Generate visualizations and reports

## Output

The tool generates several outputs in the specified output directory:
- `network-graph.png`: Visualization of rules and their data sources
- `coverage-heatmap.png`: Heatmap showing rule type coverage
- `coverage-report.html`: Detailed HTML report
- Log files in the `logs` directory

## Project Structure

```
sentinel-coverage-analyzer/
├── src/
│   └── modules/           # PowerShell modules
├── docs/                  # Documentation
├── examples/              # Example configurations and queries
├── install-dependencies.ps1
├── Start-CoverageAnalysis.ps1
├── Connect-SentinelAnalyzer.ps1
├── config.example.json
└── README.md
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
