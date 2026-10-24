[CmdletBinding()]
param(
    [ValidateSet(2, 3)][int]$SyncStages = 2,
    [ValidateRange(1, 2147483647)][int]$Seed = 1,
    [ValidateRange(90, 100000)][int]$Operations = 5000,
    [ValidateRange(0, 100000)][int]$AReadPhasePs = 1000,
    [ValidateRange(0, 100000)][int]$BWritePhasePs = 2500,
    [ValidateRange(0, 100000)][int]$BReadPhasePs = 500,
    [ValidateSet(4, 32)][int]$CountWidth = 32,
    [ValidateRange(0, 100000)][int]$AutoRefreshCycles = 0,
    [switch]$Hysteresis,
    [string]$BuildRoot = 'D:\fifo_sim',
    [string]$SimulatorBin = 'D:\altera\14.1\modelsim_ase\win32aloem'
)
$ErrorActionPreference = 'Stop'
$taskRepo = Split-Path -Parent $PSScriptRoot
$taskRoot = [IO.Path]::GetFullPath($BuildRoot)
if ($taskRoot -match '[^\x00-\x7f]') { throw 'BuildRoot must use an ASCII-only path.' }
$taskH = [int][bool]$Hysteresis
$taskName = "dual_s${SyncStages}_seed${Seed}_a${AReadPhasePs}_bw${BWritePhasePs}_br${BReadPhasePs}_c${CountWidth}_h${taskH}_auto${AutoRefreshCycles}_n${Operations}"
$taskBuild = Join-Path $taskRoot $taskName
$taskReports = Join-Path $taskRepo 'reports\dual\logs'
New-Item -ItemType Directory -Force -Path $taskBuild, $taskReports | Out-Null
foreach ($taskSubdir in @('rtl', 'tb', 'sim')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $taskBuild $taskSubdir) | Out-Null
}
$taskFiles = @('rtl/reset_sync.v','rtl/gray_sync.v','rtl/fifo_ram.v','rtl/async_fifo.v',
    'rtl/snapshot_mailbox.v','rtl/fifo_monitor.v','rtl/dual_async_fifo.v',
    'tb/fifo_channel_checker.sv','tb/snapshot_source_checker.sv','tb/dual_fifo_tb.sv',
    'sim/dual_rtl.f','sim/dual_tb.f')
foreach ($taskFile in $taskFiles) {
    Copy-Item -LiteralPath (Join-Path $taskRepo $taskFile) -Destination (Join-Path $taskBuild $taskFile)
}
foreach ($taskTool in @('vmap','vlib','vlog','vsim')) {
    if (!(Test-Path -LiteralPath (Join-Path $SimulatorBin "$taskTool.exe"))) { throw "Missing simulator tool: $taskTool" }
}
$taskAf = 224; $taskAe = 32
if ($Hysteresis) { $taskAf = 220; $taskAe = 36 }
$taskSimArgs = @('-onfinish','stop','-sv_seed',"$Seed","-gSYNC_STAGES=$SyncStages",
    "-gCOUNT_WIDTH=$CountWidth","-gAF_CLEAR=$taskAf","-gAE_CLEAR=$taskAe",
    "-gAUTO_REFRESH_CYCLES=$AutoRefreshCycles",'work.dual_fifo_tb',"+OPS=$Operations",
    "+A_RD_PHASE_PS=$AReadPhasePs","+B_WR_PHASE_PS=$BWritePhasePs","+B_RD_PHASE_PS=$BReadPhasePs")
function Invoke-DualTool {
    param([string]$Name,[string[]]$ToolArgs,[string]$LogName)
    & (Join-Path $SimulatorBin "$Name.exe") @ToolArgs *> $LogName
    if ($LASTEXITCODE -ne 0) {
        Get-Content -LiteralPath $LogName | Write-Host
        throw "$Name failed; see $LogName"
    }
}
Push-Location -LiteralPath $taskBuild
try {
    if (!(Test-Path -LiteralPath 'modelsim.ini')) { Invoke-DualTool 'vmap' @('-c') 'mapping.log' }
    if (!(Test-Path -LiteralPath 'work')) { Invoke-DualTool 'vlib' @('work') 'library.log' }
    Invoke-DualTool 'vlog' @('-work','work','-f','sim/dual_rtl.f') 'compile_rtl.log'
    Invoke-DualTool 'vlog' @('-sv','-work','work','-f','sim/dual_tb.f') 'compile_tb.log'
    Invoke-DualTool 'vsim' (@('-c','-l','run.log') + $taskSimArgs + @('-do','run -all; quit -f')) 'simulator_stdout.log'
    $taskText = Get-Content -LiteralPath 'run.log' -Raw
    if (($taskText -notmatch 'RESULT: PASS') -or ($taskText -match 'RESULT: FAIL|CHECK_FAIL|TIMEOUT|PARAMETER_ERROR|\*\* (Error|Fatal):')) {
        throw "Self-check failed or did not complete: $taskBuild/run.log"
    }
    $taskFinal = Join-Path $taskReports "$taskName.log"
    Copy-Item -LiteralPath 'run.log' -Destination $taskFinal
    $taskForward = $taskBuild.Replace('\','/')
    $taskGui = @("cd {$taskForward}",'transcript file gui_run.log','vmap work work',
        ('vsim ' + ($taskSimArgs -join ' ')),
        'add wave sim:/dual_fifo_tb/wr_clk sim:/dual_fifo_tb/rd_clk sim:/dual_fifo_tb/monitor_clk sim:/dual_fifo_tb/rst_n',
        'add wave sim:/dual_fifo_tb/wr_en sim:/dual_fifo_tb/rd_en sim:/dual_fifo_tb/rd_ready',
        'add wave sim:/dual_fifo_tb/full sim:/dual_fifo_tb/empty sim:/dual_fifo_tb/af sim:/dual_fifo_tb/ae',
        'add wave sim:/dual_fifo_tb/snapshot_req sim:/dual_fifo_tb/snapshot_ready sim:/dual_fifo_tb/snapshot_busy sim:/dual_fifo_tb/snapshot_valid',
        'add wave -radix unsigned sim:/dual_fifo_tb/snapshot_id sim:/dual_fifo_tb/dut/u_monitor/state',
        'add wave -radix hexadecimal sim:/dual_fifo_tb/aw sim:/dual_fifo_tb/ar sim:/dual_fifo_tb/bw sim:/dual_fifo_tb/br',
        'onbreak {wave zoom full}','run -all','wave zoom full')
    [IO.File]::WriteAllLines((Join-Path $taskBuild 'run_gui.do'),$taskGui,[Text.Encoding]::ASCII)
    Write-Host $taskName
    $taskText -split "`n" | Where-Object { $_ -match 'RESULT: PASS|CUSTOM_COVERAGE:|CHANNEL_[AB]:' } | ForEach-Object { Write-Host $_ }
    Write-Host "Log: $taskFinal"
    Write-Host "GUI: do {$taskForward/run_gui.do}"
} finally {
    Pop-Location
}
