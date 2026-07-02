<#
.SYNOPSIS
    BLB Safe Renamer - safe batch rename tool driven by rename_map.txt

.DESCRIPTION
    Reads a rename map file (lines in the form: ren "source" "target"),
    validates each entry, resolves duplicate target names by appending
    _002, _003, ... before the extension, and either simulates (DRYRUN)
    or performs (EXECUTE) the rename. All results are written to a CSV
    log under the logs folder.

    Compatible with Windows PowerShell 5.x. No external libraries.

.PARAMETER ListPath
    Path to the rename map file. Default: <BaseDir>\rename_map.txt

.PARAMETER BaseDir
    Target folder containing the files to rename. Default: script folder.

.PARAMETER Execute
    When specified, actually renames files (EXECUTE mode).
    When omitted, runs in DRYRUN mode (no file is changed).
#>
[CmdletBinding()]
param(
    [string]$ListPath,
    [string]$BaseDir,
    [switch]$Execute
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------
# Resolve BaseDir / ListPath / Mode
# ---------------------------------------------------------------
# When called from a BAT as -BaseDir "%~dp0", the trailing backslash
# escapes the closing quote and a stray '"' reaches this script
# (e.g. D:\Folder"). '"' is never valid in a path, so trim it.
if ($BaseDir)  { $BaseDir  = $BaseDir.TrimEnd('"')  }
if ($ListPath) { $ListPath = $ListPath.TrimEnd('"') }

if ([string]::IsNullOrWhiteSpace($BaseDir)) {
    $BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
try {
    $BaseDir = (Resolve-Path -LiteralPath $BaseDir).ProviderPath
} catch {
    Write-Host "ERROR: BaseDir not found: $BaseDir"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($ListPath)) {
    $ListPath = Join-Path $BaseDir 'rename_map.txt'
}

$mode = 'DRYRUN'
if ($Execute) { $mode = 'EXECUTE' }

# ---------------------------------------------------------------
# Prepare logs folder and log path
# ---------------------------------------------------------------
$logDir = Join-Path $BaseDir 'logs'
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logPath = Join-Path $logDir ("rename_result_{0}.csv" -f $timestamp)

Write-Host ""
Write-Host ("Mode: {0}" -f $mode)
Write-Host ("BaseDir: {0}" -f $BaseDir)
Write-Host ("ListPath: {0}" -f $ListPath)
Write-Host ("LogPath: {0}" -f $logPath)
Write-Host ""

# ---------------------------------------------------------------
# Validate rename map existence
# ---------------------------------------------------------------
if (-not (Test-Path -LiteralPath $ListPath -PathType Leaf)) {
    Write-Host ("ERROR: rename map not found: {0}" -f $ListPath)
    exit 1
}

# ---------------------------------------------------------------
# Load current file names in BaseDir (top level only, no subfolders)
# ---------------------------------------------------------------
# namesInUse simulates the folder state: existing files plus targets
# already assigned by earlier lines. Windows file names are
# case-insensitive, so comparisons use OrdinalIgnoreCase.
$namesInUse  = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$seenSources = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

Get-ChildItem -LiteralPath $BaseDir -File | ForEach-Object {
    [void]$namesInUse.Add($_.Name)
}

# ---------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------
$reservedNames = @(
    'CON','PRN','AUX','NUL',
    'COM1','COM2','COM3','COM4','COM5','COM6','COM7','COM8','COM9',
    'LPT1','LPT2','LPT3','LPT4','LPT5','LPT6','LPT7','LPT8','LPT9'
)

function Test-InvalidTarget {
    param([string]$Name)
    # Returns a reason string when the name is invalid, otherwise $null.
    if ($Name -match '[<>:"/\\|?*]') {
        return 'target filename contains invalid Windows character'
    }
    if ($Name -match '[ .]$') {
        return 'target filename ends with space or period'
    }
    # Windows evaluates reserved device names against the part before
    # the FIRST dot (e.g. "CON.tar.gz" is still invalid), so do the same.
    $baseName = $Name.Split('.')[0]
    foreach ($reserved in $reservedNames) {
        if ($baseName -ieq $reserved) {
            return 'target filename is a Windows reserved name'
        }
    }
    return $null
}

# ---------------------------------------------------------------
# Process rename map line by line
# ---------------------------------------------------------------
$results = New-Object 'System.Collections.Generic.List[object]'
$renPattern = '^\s*ren\s+"([^"]+)"\s+"([^"]+)"\s*$'

function New-ResultRow {
    param($LineNo, $Status, $Source, $TargetRequested, $TargetActual, $Reason, $ErrorText)
    [PSCustomObject]@{
        Time            = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Mode            = $mode
        LineNo          = $LineNo
        Status          = $Status
        Source          = $Source
        TargetRequested = $TargetRequested
        TargetActual    = $TargetActual
        Reason          = $Reason
        Error           = $ErrorText
    }
}

$lines = Get-Content -LiteralPath $ListPath -Encoding UTF8
$lineNo = 0

foreach ($line in $lines) {
    $lineNo++

    # Blank lines and comment lines (rem / ::) are silently skipped.
    if ($line -match '^\s*$') { continue }
    if ($line -match '^\s*(rem(\s|$)|::)') { continue }

    # --- parse -------------------------------------------------
    if ($line -notmatch $renPattern) {
        $results.Add((New-ResultRow $lineNo 'SKIP_PARSE' '' '' '' 'line is not simple ren format' ''))
        continue
    }
    $source = $Matches[1]
    $target = $Matches[2]

    # --- duplicate source check --------------------------------
    if ($seenSources.Contains($source)) {
        $results.Add((New-ResultRow $lineNo 'SKIP_DUPLICATE_SOURCE' $source $target '' 'same source file appears multiple times' ''))
        continue
    }
    [void]$seenSources.Add($source)

    # --- source existence check --------------------------------
    if (-not $namesInUse.Contains($source)) {
        $results.Add((New-ResultRow $lineNo 'SKIP_SOURCE_MISSING' $source $target '' 'source file not found' ''))
        continue
    }

    # --- target name validation --------------------------------
    $invalidReason = Test-InvalidTarget -Name $target
    if ($null -ne $invalidReason) {
        $results.Add((New-ResultRow $lineNo 'SKIP_INVALID_TARGET' $source $target '' $invalidReason ''))
        continue
    }

    # --- duplicate target resolution ---------------------------
    # The source name disappears when renamed, so it must not count
    # as a collision against its own target (e.g. case-only rename).
    [void]$namesInUse.Remove($source)

    $targetActual = $target
    $reason = ''
    if ($namesInUse.Contains($targetActual)) {
        $baseName  = [System.IO.Path]::GetFileNameWithoutExtension($target)
        $extension = [System.IO.Path]::GetExtension($target)
        $counter = 2
        do {
            $targetActual = ('{0}_{1:000}{2}' -f $baseName, $counter, $extension)
            $counter++
        } while ($namesInUse.Contains($targetActual))
        $reason = 'target duplicated; numbered filename assigned'
    }

    # --- rename (EXECUTE) or simulate (DRYRUN) -----------------
    if ($Execute) {
        try {
            Rename-Item -LiteralPath (Join-Path $BaseDir $source) -NewName $targetActual -ErrorAction Stop
            [void]$namesInUse.Add($targetActual)
            $results.Add((New-ResultRow $lineNo 'OK' $source $target $targetActual $reason ''))
        } catch {
            # Rename failed: the source file is still there.
            [void]$namesInUse.Add($source)
            $results.Add((New-ResultRow $lineNo 'ERROR_RENAME_FAILED' $source $target $targetActual $reason $_.Exception.Message))
        }
    } else {
        [void]$namesInUse.Add($targetActual)
        $results.Add((New-ResultRow $lineNo 'DRYRUN_OK' $source $target $targetActual $reason ''))
    }
}

# ---------------------------------------------------------------
# Write CSV log and show summary
# ---------------------------------------------------------------
if ($results.Count -gt 0) {
    $results | Export-Csv -LiteralPath $logPath -NoTypeInformation -Encoding UTF8
} else {
    # Always leave a log file, even when every line was skipped silently.
    New-ResultRow 0 'NO_ENTRIES' '' '' '' 'rename map contains no valid entries' '' |
        Export-Csv -LiteralPath $logPath -NoTypeInformation -Encoding UTF8
}

Write-Host "Summary:"
$results | Group-Object Status | Sort-Object Name | Select-Object Name, Count | Format-Table -AutoSize | Out-String | Write-Host

Write-Host "Finished."
exit 0
