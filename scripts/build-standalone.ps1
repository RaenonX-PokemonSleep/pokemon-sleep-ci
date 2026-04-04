# Build standalone deployment folder
# This script does everything needed for making a standalone artifact

$ErrorActionPreference = "Stop"

Write-Host -ForegroundColor Cyan "Preparing standalone deployment..."

# --- Copy files
$filesToCopy = @(
    # TypeScript config (needed for path alias resolution)
    "tsconfig.json",
    # Yarn for dependency install at the deployment site
    ".yarnrc.yml",
    # Production hosting config
    "pm2.yml",
    # Cache purging script
    "scripts/purge-cache.js",
    # Discord webhook script
    "scripts/ci/scripts/discord-webhook.ps1"
)

foreach ($sourcePath in $filesToCopy) {
    Write-Host -ForegroundColor Cyan "Copying file $sourcePath..."

    $destinationPath = ".next/standalone/$sourcePath"
    $destinationDir = Split-Path -Path $destinationPath -Parent

    # Create the parent directory if it doesn't exist
    if ($destinationDir -and -not (Test-Path -Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    if (Test-Path -Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $destinationPath -Force
    } else {
        Write-Host -ForegroundColor Yellow "Warning: $sourcePath does not exist, skipping..."
    }
}

# --- Copy folders
$foldersToCopy = @(
    # Branding images
    "public",
    # External binaries, primarily for game sync
    ".bin",
    # Static assets (chunks)
    ".next/static",
    # Source folder (needed for path resolution in migrations)
    "src",
    # Database migrations
    "migrations"
)

foreach ($sourcePath in $foldersToCopy) {
    Write-Host -ForegroundColor Cyan "Copying folder $sourcePath..."

    $destinationPath = ".next/standalone/$sourcePath"

    # Create the destination directory if it doesn't exist
    if (-not (Test-Path -Path $destinationPath)) {
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
    }

    if (Test-Path -Path $sourcePath) {
        # Copy all contents of the folder
        Copy-Item -Path "$sourcePath/*" -Destination $destinationPath -Recurse -Force
    } else {
        Write-Host -ForegroundColor Yellow "Warning: $sourcePath does not exist, skipping..."
    }
}

# --- Remove postinstall script from package.json
# `postinstall` is removed because the standalone build doesn't really need to build the lib anymore.
# `postinstall` triggers the build of the libs, causing errors.
Write-Host -ForegroundColor Cyan "Removing postinstall script from package.json..."
$packageJsonPath = ".next/standalone/package.json"
$json = Get-Content -Path $packageJsonPath -Raw | ConvertFrom-Json
if ($json.scripts -and $json.scripts.postinstall) {
    $json.scripts.PSObject.Properties.Remove('postinstall')
    $json | ConvertTo-Json -Depth 10 | Set-Content -Path $packageJsonPath
    Write-Host "postinstall script removed."
}

# Next.js 16 writes a constant 'build-TfctsWXpff2fKS' to .next/BUILD_ID when `deploymentId`
# is configured (skew protection). Restore the correct build ID (already computed by
# next.config.ts and stored in required-server-files.json as `config.deploymentId`) so that
# deployment-site scripts (e.g. discord-webhook.ps1) which fall back to this file still show
# a meaningful identifier.
# https://github.com/vercel/next.js/blob/f65b10a54d9abb2ceb3890bcadc22e372f635f88/packages/next/src/build/index.ts#L916
$DeploymentId = (Get-Content ".next/required-server-files.json" -Raw | ConvertFrom-Json).config.deploymentId
if (-not [string]::IsNullOrWhiteSpace($DeploymentId)) {
    Set-Content -Path ".next/BUILD_ID" -Value $DeploymentId -NoNewline
    Write-Host -ForegroundColor Cyan "Restored .next/BUILD_ID to deployment ID: $DeploymentId"
}

Write-Host -ForegroundColor Green "Standalone deployment built successfully at: $(Get-Item ".next/standalone" | Select-Object -ExpandProperty FullName)"
