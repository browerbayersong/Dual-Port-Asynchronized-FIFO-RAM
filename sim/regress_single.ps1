[CmdletBinding()]
param(
    [string]$BuildRoot = 'D:\fifo_sim',
    [string]$SimulatorBin = 'D:\altera\14.1\modelsim_ase\win32aloem'
)
$ErrorActionPreference = 'Stop'
$taskCases = @(
    @{ SyncStages = 2; Seed = 1 },
    @{ SyncStages = 3; Seed = 1 },
    @{ SyncStages = 2; Seed = 7; ReadPhasePs = 1000 },
    @{ SyncStages = 2; Seed = 23; ReadPhasePs = 5000 },
    @{ SyncStages = 3; Seed = 101; ReadPhasePs = 500 },
    @{ SyncStages = 3; Seed = 2026; WriteHalfPs = 17500; ReadHalfPs = 5000; ReadPhasePs = 2500 },
    @{ SyncStages = 2; Seed = 37; WriteHalfPs = 5000; ReadHalfPs = 23000; ReadPhasePs = 500 },
    @{ SyncStages = 3; Seed = 11; CountWidth = 4 },
    @{ SyncStages = 2; Seed = 13; Hysteresis = $true }
)
$taskPassed = 0
foreach ($taskCase in $taskCases) {
    & (Join-Path $PSScriptRoot 'run_single.ps1') @taskCase -BuildRoot $BuildRoot -SimulatorBin $SimulatorBin
    $taskPassed++
}
Write-Host "REGRESSION: PASS $taskPassed/$($taskCases.Count) configurations"
