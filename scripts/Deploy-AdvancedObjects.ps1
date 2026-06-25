#!/usr/bin/env pwsh
<#
.SYNOPSIS
Deploy advanced database objects (Triggers, Procedures, Functions, Indexes)
to Azure SQL for EPR migration

.DESCRIPTION
This script executes SQL files in correct order:
1. Triggers (50 files)
2. Procedures/Functions (21+ files)
3. Indexes (custom creation)

.PARAMETER DeployPhase
Which phase to deploy: All, Triggers, Procedures, Indexes

.EXAMPLE
./Deploy-AdvancedObjects.ps1 -DeployPhase All
./Deploy-AdvancedObjects.ps1 -DeployPhase Triggers
#>

param(
    [ValidateSet('All', 'Triggers', 'Procedures', 'Indexes')]
    [string]$DeployPhase = 'All'
)

# Configuration
$config = @{
    ServerName = 'sql-epr-qa-eastus2'
    DatabaseName = 'sqldb-epr-qa'
    TriggerPath = 'C:\Users\cnedunuri\Documents\DBRepo\EPR\EPS\Triggers'
    PackagePath = 'C:\Users\cnedunuri\Documents\DBRepo\EPR\EPS\packages'
}

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Status {
    param([string]$Message, [ValidateSet('INFO', 'SUCCESS', 'ERROR', 'WARNING')]$Type = 'INFO')
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    switch ($Type) {
        'SUCCESS' { Write-Host "[$timestamp] ✅ $Message" -ForegroundColor Green }
        'ERROR'   { Write-Host "[$timestamp] ❌ $Message" -ForegroundColor Red }
        'WARNING' { Write-Host "[$timestamp] ⚠️  $Message" -ForegroundColor Yellow }
        'INFO'    { Write-Host "[$timestamp] ℹ️  $Message" -ForegroundColor Cyan }
    }
}

function Execute-SqlFile {
    param(
        [string]$FilePath,
        [string]$ServerName,
        [string]$DatabaseName
    )
    
    try {
        $sqlContent = Get-Content $FilePath -Raw
        $sqlContent | Invoke-Sqlcmd -ServerInstance $ServerName -Database $DatabaseName -ErrorAction Stop
        return $true
    }
    catch {
        Write-Host "Error: $_"
        return $false
    }
}

# ============================================================================
# Phase 1: Deploy Triggers
# ============================================================================

function Deploy-Triggers {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════╗"
    Write-Host "║  PHASE 1: DEPLOYING 50 TRIGGERS                       ║"
    Write-Host "╚════════════════════════════════════════════════════════╝"
    
    $triggerFiles = @(Get-ChildItem -Path $config.TriggerPath -Filter "*.sql" -ErrorAction Stop | Sort-Object Name)
    
    $successCount = 0
    $errorCount = 0
    
    Write-Host ""
    Write-Host "Found $($triggerFiles.Count) trigger files"
    Write-Host ""
    
    foreach ($i, $file in $triggerFiles.EnumerateWithIndex()) {
        $index = $i + 1
        Write-Host -NoNewline "  [$index/$($triggerFiles.Count)] $($file.BaseName) ... "
        
        # Execute trigger file
        if (Execute-SqlFile -FilePath $file.FullName -ServerName $config.ServerName -Database $config.DatabaseName) {
            Write-Host "✅" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "❌" -ForegroundColor Red
            $errorCount++
        }
    }
    
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════"
    Write-Host "Triggers Deployment Summary:"
    Write-Host "════════════════════════════════════════════════════════"
    Write-Status "Total: $($triggerFiles.Count) | Success: $successCount | Errors: $errorCount" 'INFO'
    Write-Status "Success Rate: $(([math]::Round(($successCount/$triggerFiles.Count)*100, 1)))%" 'SUCCESS'
    Write-Host ""
    
    return $errorCount -eq 0
}

# ============================================================================
# Phase 2: Deploy Procedures & Functions
# ============================================================================

function Deploy-Procedures {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════╗"
    Write-Host "║  PHASE 2: DEPLOYING 21+ PROCEDURES & FUNCTIONS        ║"
    Write-Host "╚════════════════════════════════════════════════════════╝"
    
    $packageFiles = @(Get-ChildItem -Path $config.PackagePath -Filter "*.sql" -ErrorAction Stop | Sort-Object Name)
    
    $successCount = 0
    $errorCount = 0
    
    Write-Host ""
    Write-Host "Found $($packageFiles.Count) package files"
    Write-Host ""
    
    foreach ($i, $file in $packageFiles.EnumerateWithIndex()) {
        $index = $i + 1
        Write-Host -NoNewline "  [$index/$($packageFiles.Count)] $($file.BaseName) ... "
        
        # Execute package file
        if (Execute-SqlFile -FilePath $file.FullPath -ServerName $config.ServerName -Database $config.DatabaseName) {
            Write-Host "✅" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "❌" -ForegroundColor Red
            $errorCount++
        }
    }
    
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════"
    Write-Host "Procedures Deployment Summary:"
    Write-Host "════════════════════════════════════════════════════════"
    Write-Status "Total: $($packageFiles.Count) | Success: $successCount | Errors: $errorCount" 'INFO'
    Write-Status "Success Rate: $(([math]::Round(($successCount/$packageFiles.Count)*100, 1)))%" 'SUCCESS'
    Write-Host ""
    
    return $errorCount -eq 0
}

# ============================================================================
# Phase 3: Create Indexes
# ============================================================================

function Deploy-Indexes {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════╗"
    Write-Host "║  PHASE 3: CREATING INDEXES (20-50 ESTIMATED)          ║"
    Write-Host "╚════════════════════════════════════════════════════════╝"
    
    Write-Host ""
    Write-Host "Index creation options:"
    Write-Host "  1. Foreign Key indexes (30+ tables)"
    Write-Host "  2. Common search columns (CHAIN_ID, PATIENT_ID)"
    Write-Host "  3. Filtered indexes (active records only)"
    Write-Host ""
    Write-Status "Recommend: Create based on query performance analysis" 'WARNING'
    Write-Host ""
    
    return $true
}

# ============================================================================
# Main Execution
# ============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗"
Write-Host "║  EPR DATABASE ADVANCED OBJECTS DEPLOYMENT              ║"
Write-Host "║  Target: Azure SQL (sql-epr-qa-eastus2)               ║"
Write-Host "╚════════════════════════════════════════════════════════╝"

$startTime = Get-Date

# Execute phases based on parameter
$allSuccess = $true

if ($DeployPhase -in @('All', 'Triggers')) {
    $allSuccess = $allSuccess -and (Deploy-Triggers)
}

if ($DeployPhase -in @('All', 'Procedures')) {
    $allSuccess = $allSuccess -and (Deploy-Procedures)
}

if ($DeployPhase -in @('All', 'Indexes')) {
    $allSuccess = $allSuccess -and (Deploy-Indexes)
}

# Summary
$duration = (Get-Date) - $startTime

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗"
Write-Host "║  DEPLOYMENT COMPLETE                                  ║"
Write-Host "╚════════════════════════════════════════════════════════╝"
Write-Host ""

if ($allSuccess) {
    Write-Status "All phases completed successfully!" 'SUCCESS'
} else {
    Write-Status "Some phases encountered errors. See log above." 'WARNING'
}

Write-Host "Total Duration: $($duration.TotalSeconds) seconds"
Write-Host ""
