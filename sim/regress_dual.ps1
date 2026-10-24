[CmdletBinding()]
param(
    [string]$BuildRoot = 'D:\fifo_sim',
    [string]$SimulatorBin = 'D:\altera\14.1\modelsim_ase\win32aloem'
)
$ErrorActionPreference = 'Stop'
$taskCases = @(
    @{SyncStages=2;Seed=1},
    @{SyncStages=3;Seed=1},
    @{SyncStages=2;Seed=7;AReadPhasePs=0;BWritePhasePs=0;BReadPhasePs=0},
    @{SyncStages=2;Seed=23;AReadPhasePs=5000;BWritePhasePs=1000;BReadPhasePs=1500},
    @{SyncStages=3;Seed=101;AReadPhasePs=500;BWritePhasePs=7250;BReadPhasePs=3750},
    @{SyncStages=2;Seed=37;CountWidth=4},
    @{SyncStages=3;Seed=11;Hysteresis=$true},
    @{SyncStages=2;Seed=13;AutoRefreshCycles=8},
    @{SyncStages=2;Seed=19;AutoRefreshCycles=32},
    @{SyncStages=3;Seed=2026;AutoRefreshCycles=8;CountWidth=4;Hysteresis=$true}
)
$taskPassed = 0
foreach ($taskCase in $taskCases) {
    & (Join-Path $PSScriptRoot 'run_dual.ps1') @taskCase -BuildRoot $BuildRoot -SimulatorBin $SimulatorBin
    $taskPassed++
}
Write-Host "DUAL_REGRESSION: PASS $taskPassed/$($taskCases.Count) configurations"
