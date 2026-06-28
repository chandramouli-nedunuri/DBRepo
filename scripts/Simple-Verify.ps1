# Simple verification - check if any tables got partitioned
# This file will save results to a text file we can read

$results = @()

$tables = @("RX_TX", "PRESCRIBER", "MRN", "CARD", "PAYMENT", "LINE_ITEM", "ALLERGY", "DISEASE")

foreach ($t in $tables) {
    try {
        $result = & "C:\Users\cnedunuri\Documents\DBRepo\scripts\Connect-ToDatabase.ps1" -Query "SELECT COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.$t') AND index_id=1" 2>&1
        
        # Extract the partition count from result
        if ($result -match ":\s*(\d+)\s*$") {
            $count = [int]$matches[1]
        } else {
            $count = -1  # Error
        }
        
        $status = if ($count -eq 6) { "PASS" } elseif ($count -eq 1) { "NOT PARTITIONED" } else { "ERROR: $count" }
        $results += "$t : $count partitions - $status"
    }
    catch {
        $results += "$t : ERROR - $_"
    }
    
    Start-Sleep -Milliseconds 500
}

# Save to file
$results | Out-File "C:\Users\cnedunuri\Documents\DBRepo\verification_results.txt" -Force

# Also print
$results | ForEach-Object { Write-Host $_ }

Write-Host "`nResults saved to verification_results.txt"
