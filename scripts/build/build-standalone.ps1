# Build standalone deployment folder
# This script does everything needed for making a standalone artifact

$ErrorActionPreference = "Stop"

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'build-actions.psm1') -Force

$nextBuildRoot = '.next'
$standaloneRoot = Join-Path -Path $nextBuildRoot -ChildPath 'standalone'

Write-Host -ForegroundColor Cyan "Preparing standalone deployment..."

Assert-StandaloneBuildOutput -NextBuildRoot $nextBuildRoot -StandaloneRoot $standaloneRoot

Copy-StandaloneFiles -StandaloneRoot $standaloneRoot -SourcePaths @(
    # TypeScript config (needed for path alias resolution)
    'tsconfig.json',
    # Yarn files for dependency install at the deployment site
    'yarn.lock',
    '.yarnrc.yml',
    # Node runtime version to run at the deployment site
    '.nvmrc',
    # Production hosting config
    'pm2.yml',
    # Cache purging script
    'scripts/purge-cache.js',
    # Discord webhook script
    'scripts/ci/scripts/discord-webhook.ps1'
)

Copy-StandaloneFolders -StandaloneRoot $standaloneRoot -SourcePaths @(
    # Branding images
    'public',
    # External binaries, primarily for game sync
    '.bin',
    # Static assets (chunks)
    '.next/static',
    # Source folder (needed for path resolution in migrations)
    'src',
    # Database migrations
    'migrations'
)

# Calc Server is a separate Bun entry, so Next.js does not trace its runtime dependencies.
Copy-StandalonePackages -StandaloneRoot $standaloneRoot -NodeModulesRoot 'node_modules' -PackageNames @(
    'glpk.js',
    'highs',
    'hono',
    'zod'
)

Remove-StandalonePostInstall -StandaloneRoot $standaloneRoot
Restore-StandaloneBuildId -NextBuildRoot $nextBuildRoot

$standalonePath = Get-Item -LiteralPath $standaloneRoot | Select-Object -ExpandProperty FullName
Write-Host -ForegroundColor Green "Standalone deployment built successfully at: $standalonePath"
