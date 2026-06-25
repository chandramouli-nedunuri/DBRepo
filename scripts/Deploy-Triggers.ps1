#!/usr/bin/env pwsh
<#
.SYNOPSIS
Deploy all 50 triggers to Azure SQL Database

.DESCRIPTION
Executes all trigger files from EPR/EPS/Triggers/ directory
Handles GO statements by stripping them and executing via Connect-ToDatabase.ps1

.PARAMETER TriggerPath
Path to triggers directory

.PARAMETER BatchSize
Number of triggers to execute in parallel (default: 1 for sequential)
#>

param(
    [string]$TriggerPath = "c:\Users\cnedunuri\Documents\DBRepo\EPR\EPS\Triggers",
    [int]$BatchSize = 1
)

# Get all trigger files
$triggerFiles = @(Get-ChildItem -Path $TriggerPath -Filter "*.sql" | Where-Object { $_.Name -notlike "*BATCH*" } | Sort-Object Name)

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗"
Write-Host "║  DEPLOYING 50 TRIGGERS TO AZURE SQL                   ║"
Write-Host "╚════════════════════════════════════════════════════════╝"
Write-Host ""
Write-Host "Found $($triggerFiles.Count) trigger files"
Write-Host ""

$successCount = 0
$errorCount = 0
$errors = @()

for ($i = 0; $i -lt $triggerFiles.Count; $i++) {
    $file = $triggerFiles[$i]
    $index = $i + 1
    $triggerName = $file.BaseName
    
    Write-Host -NoNewline "[$index/50] $triggerName ... "
    
    try {
        # Read trigger file
        $triggerContent = Get-Content $file.FullName -Raw
        
        # Split by GO and execute each batch separately
        $batches = $triggerContent -split '\bGO\b' | Where-Object { $_.Trim().Length -gt 0 }
        
        $batchError = $false
        foreach ($batch in $batches) {
            # Execute via Connect-ToDatabase.ps1
            $output = & "c:\Users\cnedunuri\Documents\DBRepo\scripts\Connect-ToDatabase.ps1" -Query $batch 2>&1 | Out-String
            
            if ($output -like "*ERROR*" -or $output -like "*Exception*" -or $output -like "*error*") {
                $batchError = $true
                $errors += @{
                    trigger = $triggerName
                    error = ($output | Select-String -Pattern "ERROR|Exception|error" | Select-Object -First 1 -ExpandProperty Line)
                }
                break
            }
        }
        
        if (-not $batchError) {
            Write-Host "✅" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "❌" -ForegroundColor Red
            $errorCount++
        }
    } catch {
        Write-Host "❌" -ForegroundColor Red
        $errorCount++
        $errors += @{
            trigger = $triggerName
            error = $_.Exception.Message
        }
    }
    
    # Progress checkpoint every 10 triggers
    if (($index % 10) -eq 0) {
        Write-Host "   ✓ Progress: $index/50 (Success: $successCount, Errors: $errorCount)"
    }
}

# Summary
Write-Host ""
Write-Host "════════════════════════════════════════════════════════"
Write-Host "TRIGGER DEPLOYMENT SUMMARY"
Write-Host "════════════════════════════════════════════════════════"
Write-Host "Total Triggers:   50"
Write-Host "Successful:       $successCount ✅"
Write-Host "Failed:           $errorCount ❌"
Write-Host "Success Rate:     $(([math]::Round(($successCount/50)*100, 1)))%"
Write-Host ""

if ($errorCount -gt 0) {
    Write-Host "ERRORS ENCOUNTERED:"
    Write-Host "════════════════════════════════════════════════════════"
    $errors | ForEach-Object {
        Write-Host "  [$($_.trigger)]"
        Write-Host "    Error: $($_.error)"
    }
    Write-Host ""
}

# Verify in Azure SQL
Write-Host "VERIFICATION:"
Write-Host "════════════════════════════════════════════════════════"
& "c:\Users\cnedunuri\Documents\DBRepo\scripts\Connect-ToDatabase.ps1" -Query @"
SELECT COUNT(*) as TriggerCount FROM sys.triggers;
"@

Write-Host ""
