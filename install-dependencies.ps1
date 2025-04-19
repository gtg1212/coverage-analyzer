# Detect OS
$isWindowsOS = ($PSVersionTable.PSVersion.Major -lt 6) -or ($PSVersionTable.Platform -eq 'Win32NT') -or $IsWindows
$isLinuxOS = $IsLinux -or ($PSVersionTable.Platform -eq 'Unix')
Write-Host "Detected OS: $(if ($isWindowsOS) { 'Windows' } else { 'Linux' })"

# Install system dependencies
Write-Host "`nInstalling system dependencies..."
if ($isLinuxOS) {
    Write-Host "Installing Linux dependencies..."
    try {
        sudo apt-get -y update
        sudo apt-get install -y --no-install-recommends libgdiplus libc6-dev graphviz
    }
    catch {
        Write-Error ("Failed to install Linux dependencies: " + $_.Exception.Message)
        Write-Host "Please manually install: libgdiplus, libc6-dev, and graphviz"
    }
}
elseif ($isWindowsOS) {
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
            Write-Error ("Failed to install Chocolatey: " + $_.Exception.Message)
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
        Write-Error ("Failed to install Graphviz: " + $_.Exception.Message)
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

# Register PSGallery if not already registered
if (-not (Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue)) {
    Write-Host "Registering PSGallery repository..."
    Register-PSRepository -Default
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
}

# Install Azure modules
Write-Host "Installing Azure PowerShell modules..."
$azureModules = @(
    @{ Name = 'Az.Accounts'; Version = '2.0.0' },
    @{ Name = 'Az.SecurityInsights'; Version = '2.0.0' },
    @{ Name = 'Az.OperationalInsights'; Version = '2.0.0' }
)

foreach ($module in $azureModules) {
    try {
        $existingModule = Get-Module -ListAvailable -Name $module.Name
        if ($existingModule) {
            Write-Host ("Module " + $module.Name + " is already installed with version " + $existingModule.Version)
            if ($existingModule.Version -lt $module.Version) {
                Write-Host ("Updating " + $module.Name + " to version " + $module.Version)
                Install-Module -Name $module.Name -RequiredVersion $module.Version -Force -AllowClobber -Scope CurrentUser -Repository PSGallery
            }
        } else {
            Install-Module -Name $module.Name -RequiredVersion $module.Version -Force -AllowClobber -Scope CurrentUser -Repository PSGallery
            Write-Host ("Installed " + $module.Name + " version " + $module.Version)
        }
    }
    catch {
        Write-Error ("Failed to install " + $module.Name + ": " + $_.Exception.Message)
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
        $existingModule = Get-Module -ListAvailable -Name $module
        if (-not $existingModule) {
            Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser -Repository PSGallery
            Write-Host ("Installed " + $module)
        } else {
            Write-Host ("Module " + $module + " is already installed with version " + $existingModule.Version)
        }
    }
    catch {
        Write-Error ("Failed to install " + $module + ": " + $_.Exception.Message)
    }
}

# Verify Graphviz installation
Write-Host "`nVerifying Graphviz installation..."
try {
    $dotOutput = (dot -V) 2>&1
    if ($dotOutput -match 'version (\d+\.\d+\.\d+)') {
        $dotVersion = $matches[1]
        Write-Host ("Graphviz version: " + $dotVersion)
    } else {
        Write-Host ("Graphviz version output: " + $dotOutput)
    }
}
catch {
    Write-Error "Graphviz (dot) not found in PATH. Please ensure Graphviz is installed and added to your PATH"
}

# Verify module installations
Write-Host "`nVerifying PowerShell module installations..."
$allModules = $azureModules.Name + $otherModules
$missingModules = @()

foreach ($module in $allModules) {
    $installedModule = Get-Module -ListAvailable -Name $module | Sort-Object Version -Descending | Select-Object -First 1
    if ($installedModule) {
        Write-Host ("$module version " + $installedModule.Version + " is installed")
    }
    else {
        Write-Error ("Failed to verify installation of " + $module)
        $missingModules += $module
    }
}

# Final status
if ($missingModules.Count -gt 0) {
    Write-Warning "`nSome dependencies failed to install:"
    $missingModules | ForEach-Object { Write-Host ("- " + $_) }
    Write-Host "Please install missing dependencies manually"
}
else {
    Write-Host "`nAll dependencies installed successfully!"
} 