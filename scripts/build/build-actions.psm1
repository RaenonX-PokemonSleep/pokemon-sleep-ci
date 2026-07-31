# Reusable standalone artifact build actions.
function Assert-StandaloneBuildOutput {
    param(
        [Parameter(Mandatory)]
        [string]$NextBuildRoot,
        [Parameter(Mandatory)]
        [string]$StandaloneRoot
    )

    $requiredPaths = @(
        (Join-Path -Path $NextBuildRoot -ChildPath 'required-server-files.json'),
        (Join-Path -Path $StandaloneRoot -ChildPath 'package.json')
    )
    foreach ($requiredPath in $requiredPaths) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "Next.js standalone build output is missing: $requiredPath"
        }
    }
}

function Copy-StandaloneFiles {
    param(
        [Parameter(Mandatory)]
        [string[]]$SourcePaths,
        [Parameter(Mandatory)]
        [string]$StandaloneRoot
    )

    foreach ($sourcePath in $SourcePaths) {
        Write-Host -ForegroundColor Cyan "Copying file $sourcePath..."

        $destinationPath = Join-Path -Path $StandaloneRoot -ChildPath $sourcePath
        $destinationDir = Split-Path -Path $destinationPath -Parent

        if (Test-Path -LiteralPath $destinationPath) {
            Remove-Item -LiteralPath $destinationPath -Force
        }

        if ($destinationDir -and -not (Test-Path -LiteralPath $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        }

        if (Test-Path -LiteralPath $sourcePath) {
            Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
        } else {
            Write-Host -ForegroundColor Yellow "Warning: $sourcePath does not exist, skipping..."
        }
    }
}

function Copy-StandaloneFolders {
    param(
        [Parameter(Mandatory)]
        [string[]]$SourcePaths,
        [Parameter(Mandatory)]
        [string]$StandaloneRoot
    )

    foreach ($sourcePath in $SourcePaths) {
        Write-Host -ForegroundColor Cyan "Copying folder $sourcePath..."

        $destinationPath = Join-Path -Path $StandaloneRoot -ChildPath $sourcePath

        if (Test-Path -LiteralPath $destinationPath) {
            Remove-Item -LiteralPath $destinationPath -Recurse -Force
        }

        if (Test-Path -LiteralPath $sourcePath) {
            New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
            Copy-Item -Path (Join-Path -Path $sourcePath -ChildPath '*') -Destination $destinationPath -Recurse -Force
        } else {
            Write-Host -ForegroundColor Yellow "Warning: $sourcePath does not exist, skipping..."
        }
    }
}

function Copy-StandalonePackages {
    param(
        [Parameter(Mandatory)]
        [string[]]$PackageNames,
        [Parameter(Mandatory)]
        [string]$NodeModulesRoot,
        [Parameter(Mandatory)]
        [string]$StandaloneRoot
    )

    foreach ($packageName in $PackageNames) {
        Write-Host -ForegroundColor Cyan "Copying runtime package $packageName..."

        $sourcePath = Join-Path -Path $NodeModulesRoot -ChildPath $packageName
        $destinationPath = Join-Path -Path $StandaloneRoot -ChildPath "node_modules/$packageName"

        if (-not (Test-Path -LiteralPath $destinationPath)) {
            New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
        }

        Copy-Item -Path (Join-Path -Path $sourcePath -ChildPath '*') -Destination $destinationPath -Recurse -Force
    }
}

function Remove-StandalonePostInstall {
    param(
        [Parameter(Mandatory)]
        [string]$StandaloneRoot
    )

    # `postinstall` triggers the build of libraries that are already built in the standalone artifact.
    Write-Host -ForegroundColor Cyan "Removing postinstall script from package.json..."
    $packageJsonPath = Join-Path -Path $StandaloneRoot -ChildPath 'package.json'
    $json = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
    if ($json.scripts -and $json.scripts.postinstall) {
        $json.scripts.PSObject.Properties.Remove('postinstall')
        $json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $packageJsonPath
        Write-Host "postinstall script removed."
    }
}

function Restore-StandaloneBuildId {
    param(
        [Parameter(Mandatory)]
        [string]$NextBuildRoot
    )

    # Next.js 16 writes a constant 'build-TfctsWXpff2fKS' to .next/BUILD_ID when `deploymentId`
    # is configured (skew protection). Restore the correct build ID from required-server-files.json
    # so deployment-site scripts still show a meaningful identifier.
    # https://github.com/vercel/next.js/blob/f65b10a54d9abb2ceb3890bcadc22e372f635f88/packages/next/src/build/index.ts#L916
    $requiredServerFilesPath = Join-Path -Path $NextBuildRoot -ChildPath 'required-server-files.json'
    $deploymentId = (Get-Content -LiteralPath $requiredServerFilesPath -Raw | ConvertFrom-Json).config.deploymentId
    if (-not [string]::IsNullOrWhiteSpace($deploymentId)) {
        $buildIdPath = Join-Path -Path $NextBuildRoot -ChildPath 'BUILD_ID'
        Set-Content -LiteralPath $buildIdPath -Value $deploymentId -NoNewline
        Write-Host -ForegroundColor Cyan "Restored .next/BUILD_ID to deployment ID: $deploymentId"
    }
}

Export-ModuleMember -Function @(
    'Assert-StandaloneBuildOutput',
    'Copy-StandaloneFiles',
    'Copy-StandaloneFolders',
    'Copy-StandalonePackages',
    'Remove-StandalonePostInstall',
    'Restore-StandaloneBuildId'
)
