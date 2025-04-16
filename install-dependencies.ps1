# Install system dependencies
Write-Host "Installing system dependencies..."
sudo apt-get -y update
sudo apt-get install -y --no-install-recommends libgdiplus libc6-dev graphviz

# Install PowerShell modules
Write-Host "Installing PowerShell modules..."

# Install Azure modules
Write-Host "Installing Azure PowerShell modules..."
Install-Module -Name Az.Accounts -RequiredVersion 2.0.0 -Force -AllowClobber -Scope CurrentUser
Install-Module -Name Az.SecurityInsights -RequiredVersion 2.0.0 -Force -AllowClobber -Scope CurrentUser
Install-Module -Name Az.OperationalInsights -RequiredVersion 2.0.0 -Force -AllowClobber -Scope CurrentUser

# Install visualization and reporting modules
Write-Host "Installing visualization and reporting modules..."
Install-Module -Name PSGraph -Force -AllowClobber -Scope CurrentUser
Install-Module -Name ImportExcel -Force -AllowClobber -Scope CurrentUser

# Verify Graphviz installation
Write-Host "Verifying Graphviz installation..."
dot -V

# Verify module installations
Write-Host "Verifying module installations..."
$requiredModules = @(
    'Az.Accounts',
    'Az.SecurityInsights',
    'Az.OperationalInsights',
    'PSGraph',
    'ImportExcel'
)

foreach ($module in $requiredModules) {
    $installedModule = Get-Module -ListAvailable -Name $module
    if ($installedModule) {
        Write-Host "${module} version $($installedModule.Version) is installed"
    } else {
        Write-Error "Failed to verify installation of ${module}"
    }
}

Write-Host "`nDependencies installed successfully!" 