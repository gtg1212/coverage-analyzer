# Detect OS
$isWindows = $IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6)
$isLinux = $IsLinux
Write-Host "Detected OS: $(if ($isWindows) { 'Windows' } else { 'Linux' })"

# Install system dependencies
Write-Host "`nInstalling system dependencies..."
if ($isLinux) {
    Write-Host "Installing Linux dependencies..."
    try {
        sudo apt-get -y update
        sudo apt-get install -y --no-install-recommends libgdiplus libc6-dev graphviz
    }
    catch {
        Write-Error "Failed to install Linux dependencies: $_"
        Write-Host "Please manually install: libgdiplus, libc6-dev, and graphviz"
    }
}
elseif ($isWindows) {
    Write-Host "Installing Windows dependencies..."
    
    # Check if Chocolatey is installed
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey not found. Installing..."
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        }
        catch {
            Write-Error "Failed to install Chocolatey: $_"
            Write-Host "Please install Chocolatey manually from https://chocolatey.org/install"
            Write-Host "Then install Graphviz using: choco install graphviz"
            return
        }
    }

    # Install Graphviz using Chocolatey
    try {
        choco install graphviz -y
        refreshenv
    }
    catch {
        Write-Error "Failed to install Graphviz: $_"
        Write-Host "Please install Graphviz manually from https://graphviz.org/download/"
    }
}
else {
    Write-Warning "Unsupported operating system. Please install the following dependencies manually:"
    Write-Host "- Graphviz (https://graphviz.org/download/)"
    Write-Host "- .NET dependencies for your OS"
}

# Install PowerShell modules
Write-Host "`nInstalling PowerShell modules..."

# Install Azure modules
Write-Host "Installing Azure PowerShell modules..."
$azureModules = @(
    @{ Name = 'Az.Accounts'; Version = '2.0.0' },
    @{ Name = 'Az.SecurityInsights'; Version = '2.0.0' },
    @{ Name = 'Az.OperationalInsights'; Version = '2.0.0' }
)

foreach ($module in $azureModules) {
    try {
        Install-Module -Name $module.Name -RequiredVersion $module.Version -Force -AllowClobber -Scope CurrentUser
        Write-Host "Installed $($module.Name) version $($module.Version)"
    }
    catch {
        Write-Error "Failed to install $($module.Name): $_"
    }
}

# Install visualization and reporting modules
Write-Host "`nInstalling visualization and reporting modules..."
$otherModules = @(
    'PSGraph',
    'ImportExcel'
)

foreach ($module in $otherModules) {
    try {
        Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
        Write-Host "Installed $module"
    }
    catch {
        Write-Error "Failed to install $module: $_"
    }
}

# Verify Graphviz installation
Write-Host "`nVerifying Graphviz installation..."
try {
    $dotVersion = dot -V
    Write-Host "Graphviz version: $dotVersion"
}
catch {
    Write-Error "Graphviz (dot) not found in PATH. Please ensure Graphviz is installed and added to your PATH"
}

# Verify module installations
Write-Host "`nVerifying PowerShell module installations..."
$allModules = $azureModules.Name + $otherModules
$missingModules = @()

foreach ($module in $allModules) {
    $installedModule = Get-Module -ListAvailable -Name $module
    if ($installedModule) {
        Write-Host "$module version $($installedModule.Version) is installed"
    }
    else {
        Write-Error "Failed to verify installation of $module"
        $missingModules += $module
    }
}

# Final status
if ($missingModules.Count -gt 0) {
    Write-Warning "`nSome dependencies failed to install:"
    $missingModules | ForEach-Object { Write-Host "- $_" }
    Write-Host "Please install missing dependencies manually"
}
else {
    Write-Host "`nAll dependencies installed successfully!"
} 