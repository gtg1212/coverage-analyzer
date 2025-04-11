# Install system dependencies
Write-Host "Installing system dependencies..."
sudo apt-get -y update
sudo apt-get install -y --no-install-recommends libgdiplus libc6-dev graphviz

# Install PowerShell modules
Write-Host "Installing PowerShell modules..."
Install-Module -Name PSGraph -Force -AllowClobber -Scope CurrentUser
Install-Module -Name ImportExcel -Force -AllowClobber -Scope CurrentUser

# Verify Graphviz installation
Write-Host "Verifying Graphviz installation..."
dot -V

# Verify PSGraph installation
Write-Host "Verifying PSGraph installation..."
Get-Module -ListAvailable -Name PSGraph

Write-Host "Dependencies installed successfully!" 