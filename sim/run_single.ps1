[CmdletBinding()]
param(
    [ValidateSet(2, 3)][int]$SyncStages = 2,
    [ValidateRange(1, 2147483647)][int]$Seed = 1,
    [ValidateRange(90, 100000)][int]$Operations = 5000,
    [ValidateRange(1000, 100000)][int]$WriteHalfPs = 10000,
    [ValidateRange(1000, 100000)][int]$ReadHalfPs = 6000,
    [ValidateRange(0, 100000)][int]$ReadPhasePs = 0,
    [ValidateSet(4, 32)][int]$CountWidth = 32,
    [switch]$Hysteresis,
    [string]$BuildRoot = 'D:\fifo_sim',
    [string]$SimulatorBin = 'D:\altera\14.1\modelsim_ase\win32aloem'
)
$ErrorActionPreference = 'Stop'
$taskRepo = Split-Path -Parent $PSScriptRoot
$taskBuildRoot = [IO.Path]::GetFullPath($BuildRoot)
if ($taskBuildRoot -match '[^\x00-\x7f]') { throw 'BuildRoot must use an ASCII-only path.' }
$taskH = [int][bool]$Hysteresis
$taskName = "single_s${SyncStages}_seed${Seed}_w${WriteHalfPs}_r${ReadHalfPs}_p${ReadPhasePs}_c${CountWidth}_h${taskH}"
$taskBuild = Join-Path $taskBuildRoot $taskName
$taskReports = Join-Path $taskRepo 'reports\logs'
New-Item -ItemType Directory -Force -Path $taskBuild, $taskReports | Out-Null
foreach ($taskSubdir in @('rtl', 'tb', 'sim')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $taskBuild $taskSubdir) | Out-Null
}
$taskFiles = @('rtl/reset_sync.v', 'rtl/gray_sync.v', 'rtl/fifo_ram.v', 'rtl/async_fifo.v',
               'tb/single_fifo_tb.sv', 'sim/rtl.f', 'sim/single_tb.f')
foreach ($taskFile in $taskFiles) {
    Copy-Item -LiteralPath (Join-Path $taskRepo $taskFile) -Destination (Join-Path $taskBuild $taskFile)
}
foreach ($taskTool in @('vmap', 'vlib', 'vlog', 'vsim')) {
    if (!(Test-Path -LiteralPath (Join-Path $SimulatorBin "$taskTool.exe"))) { throw "Missing simulator tool: $taskTool" }
}
$taskAf = 224
$taskAe = 32
if ($Hysteresis) { $taskAf = 220; $taskAe = 36 }
$taskSimArgs = @('-onfinish', 'stop', '-sv_seed', "$Seed", "-gSYNC_STAGES=$SyncStages",
                 "-gCOUNT_WIDTH=$CountWidth", "-gAF_CLEAR=$taskAf", "-gAE_CLEAR=$taskAe",
                 'work.single_fifo_tb', "+OPS=$Operations", "+WR_HALF_PS=$WriteHalfPs",
                 "+RD_HALF_PS=$ReadHalfPs", "+RD_PHASE_PS=$ReadPhasePs")
function Invoke-FifoTool {
    param([string]$Name, [string[]]$ToolArgs, [string]$LogName)
    & (Join-Path $SimulatorBin "$Name.exe") @ToolArgs *> $LogName
    if ($LASTEXITCODE -ne 0) {
        Get-Content -LiteralPath $LogName | Write-Host
        throw "$Name failed; see $LogName"
    }
}
$taskRunLog = Join-Path $taskBuild 'run.log'
Push-Location -LiteralPath $taskBuild
try {
    if (!(Test-Path -LiteralPath 'modelsim.ini')) { Invoke-FifoTool 'vmap' @('-c') 'mapping.log' }
    if (!(Test-Path -LiteralPath 'work')) { Invoke-FifoTool 'vlib' @('work') 'library.log' }
    Invoke-FifoTool 'vlog' @('-work', 'work', '-f', 'sim/rtl.f') 'compile_rtl.log'
    Invoke-FifoTool 'vlog' @('-sv', '-work', 'work', '-f', 'sim/single_tb.f') 'compile_tb.log'
    $taskBatchArgs = @('-c', '-l', 'run.log') + $taskSimArgs + @('-do', 'run -all; quit -f')
    Invoke-FifoTool 'vsim' $taskBatchArgs 'simulator_stdout.log'
    $taskText = Get-Content -LiteralPath $taskRunLog -Raw
    if (($taskText -notmatch 'RESULT: PASS') -or
        ($taskText -match 'RESULT: FAIL|CHECK_FAIL|TIMEOUT|PARAMETER_ERROR|\*\* (Error|Fatal):')) {
        throw "Self-check failed or did not complete: $taskRunLog"
    }
    $taskFinal = Join-Path $taskReports "$taskName.log"
    Copy-Item -LiteralPath $taskRunLog -Destination $taskFinal
    $taskForward = $taskBuild.Replace('\', '/')
    $taskGuiLines = @(
        "cd {$taskForward}",
        'transcript file gui_run.log',
        'vmap work work',
        ('vsim ' + ($taskSimArgs -join ' ')),
        'add wave sim:/single_fifo_tb/wr_clk sim:/single_fifo_tb/rd_clk sim:/single_fifo_tb/rst_n',
        'add wave sim:/single_fifo_tb/wr_en sim:/single_fifo_tb/full sim:/single_fifo_tb/almost_full',
        'add wave sim:/single_fifo_tb/rd_en sim:/single_fifo_tb/rd_ready sim:/single_fifo_tb/empty sim:/single_fifo_tb/almost_empty',
        'add wave -radix unsigned sim:/single_fifo_tb/dut/wbin sim:/single_fifo_tb/dut/rbin sim:/single_fifo_tb/wr_level sim:/single_fifo_tb/rd_level',
        'add wave -radix hexadecimal sim:/single_fifo_tb/wr_data sim:/single_fifo_tb/rd_data',
        'add wave sim:/single_fifo_tb/rd_data_valid',
        'onbreak {wave zoom full}',
        'run -all',
        'wave zoom full'
    )
    [IO.File]::WriteAllLines((Join-Path $taskBuild 'run_gui.do'), $taskGuiLines, [Text.Encoding]::ASCII)
    $taskSummary = ($taskText -split "`n" | Where-Object { $_ -match 'RESULT: PASS|CUSTOM_COVERAGE:' }) -join "`n"
    Write-Host $taskName
    Write-Host $taskSummary
    Write-Host "Log: $taskFinal"
    Write-Host "GUI: do {$taskForward/run_gui.do}"
} finally {
    Pop-Location
}
