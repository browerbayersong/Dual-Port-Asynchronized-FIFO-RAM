# 目标器件实现与课程报告操作

2026-10-24：在软件中完成两级、三级同步版本的综合、布局布线和时序分析。评估目标为本机 TD 支持的 **PH1A100SFG676，速度等级2**，不是任务书指定器件，不需要购买开发板或烧录。

## 已交付结果

- [正式课程报告](../deliverables/双异步FIFO课程设计报告.docx)及[可检索正文](COURSE_REPORT.md)。个人信息和实际分工按用户要求留空。
- [目标实现报告](../reports/implementation/REPORT.md)：资源、时序、约束证据及警告。
- [MTBF 相对分析](../reports/mtbf/REPORT.md)：说明模型、额外稳定时间及44位寄存器代价，不填没有器件参数支持的绝对年数。
- [干净目录复现](../reports/reproduction/summary.json)：同一计算机新目录重新编译，指定配置及完整10组通过；不冒充其他成员独立复现。
- [原始波形来源](../reports/figures/waveform_manifest.json)：图形从通过的 ModelSim 运行提取。

## 实现条件与边界

工具为 Tang Dynasty V6.2.168116，线程4，布局种子1，保留层次，关闭寄存器合并、顺序优化、移位寄存器推断及IO寄存器打包。五个时钟周期依次为20、12、35、10、10 ns，显式不确定度0.2 ns，工具还计入器件默认值。端口预算采用最小0.5 ns、最大为对应周期20%，自动IO分配和默认LVCMOS33。

原始顶层端口共1038位，超过封装316个用户IO。仅用于实现评估的 [dual_fifo_eval.v](../analysis/dual_fifo_eval.v) 把统计、ID和快照844位以只读32位组合选择保留，顶层231位IO。组合封装没有时序反馈；业务RTL、参数、验证平台均未修改。资源包括封装和IO，不能把选择输出视为新的跨域接收协议。

[td_eval.sdc](../constraints/td_eval.sdc) 为展开的静态SDC；[端点审计](../constraints/td_endpoint_audit.tcl) 独立执行。TD的read_sdc不会运行任意Tcl循环，不能将含循环的文件加载成功当作约束有效。脚本拒绝默认DeriveClock并检查五个命名时钟及16组跨域端点数量。

跨域setup使用最大数据路径约束，仅对异步hold作例外，没有用全域异步组覆盖最大延迟。16组覆盖472条路径：36位Gray、8条单bit请求/确认、428位保持数据。原生报告的Dominated等于Total，Shadowed和Ignored为零。Gray每总线9位均有延迟记录。SDC还写有set_max_skew，但没有独立的原生生效报告，**不宣称该命令已独立签核**；使用逐位绝对延迟限制作保守偏斜上界，同一max corner下的位间延迟差只作参考。

完整接口视图保留IO预算。另用相同SDC筛选内部寄存器起止路径，每组报告最差20个端点，得到内部逻辑分析视图；不修改SDC或追加假路径。内部视图的正裕量不能替代IO或RAM物理检查。

三个未解决的实际问题：

1. 完整接口setup/hold WNS为-5.919/-2.794 ns，**尚未收敛**；不得将内部寄存器Fmax标成完整接口可运行频率。
2. **TMR-5506**：ERAM地址或片选由异步复位寄存器驱动，厂商提示潜在RAM数据翻转。共同复位丢弃旧队列和有效操作门控已在RTL验证，但器件物理复位行为尚无门级或厂商规则验证，不能宣称可直接部署硬件。
3. **PWR-5001 Import power lib first**：缺少匹配器件的厂商功耗库，W值为未测，JSON为null。未计算的空结果不能当作0 W。

## 运行顺序

在仓库根目录运行，Python路径按本机调整：

```powershell
$python = 'C:\Users\browersong\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $python tools/verify_eval_wrapper.py
& $python tools/run_td.py
& $python tools/summarize_td.py
& $python tools/probe_power.py
& $python tools/reproduce_clean.py
```

`run_td.py --help` 可修改 `--td-bin`、`--build-root`、`--stages 2 3`。默认TD安装在 `D:/Anlogic/TD_6.2.1_Engineer_6.2.168.116/bin`，构建位于 `D:/fifo_build/impl_s2` 和 `impl_s3`。不能使用中文构建路径。全流程不生成下载文件或调用编程器。

`--resume route` 仅对源码、封装参数、SDC与已保存数据库匹配时重新导出报告；`--resume place` 从匹配的放置结果重新布线。当前日志为最终已保存route.db的报告导出，`IMPLEMENTATION: PASS` 表示流程完成，不表示时序通过。原始flow.tcl及最终resume脚本均保留。重跑会更新当前结果，应先保存要对比的版本。

功耗探测默认两级，结温85℃、vccd=0.9 V、vccaux=1.8 V、vectorless翻转比例0.125，工具默认process=Maximum；没有SAIF活动注释。将来取得匹配功耗库后，可用 `--power-lib D:/path/model` 和 `--stages 2` 或 `3` 分别计算；脚本仍要求人工核对原生结果，不能直接把返回成功当成有效W值。

`verify_eval_wrapper.py` 对两种级数运行原有完整自检，并遍历32个选择值核对状态打包和补零。`reproduce_clean.py` 复制当前源码到全新英文目录，重新编译指定配置和完整回归，校验复制前后哈希，保留日志。它不替代T63的另一成员人工复现。

## 报告生成

独立文档依赖见 [requirements-report.txt](../tools/requirements-report.txt)。本机将它们安装在仓库外 `D:/fifo_tools/report_deps`，不修改系统环境：

```powershell
& $python -m pip install --target D:/fifo_tools/report_deps -r tools/requirements-report.txt
$env:PYTHONPATH = 'D:/fifo_tools/report_deps'
& $python tools/report_figures.py
& $python tools/build_course_report.py
& $python tools/render_course_report.py
```

绘图需要可用中文字体，本机为 `C:/Windows/Fonts/msyh.ttc`。图中数据来自真实通过运行，raw VCD保存在仓库外；MTBF图是无量纲数学曲线。报告使用python-docx生成，Word公式保持可编辑。

本机没有LibreOffice。渲染辅助程序使用已安装WPS的后台COM导出，再调用文档技能自带的PDF栅格器和Poppler，输出到 `D:/fifo_build/report_qa`。若WPS实例中已有打开文档，脚本会停止以避免影响用户文档；其他机器可直接在Word/WPS导出。报告更改后必须重新导出并逐页核对。PNG为内部排版检查产物，不作为报告交付。

厂商工具、功耗库、数据库、大网表与原始大VCD不提交仓库。课程报告可编辑源为脚本及Markdown，最终Word文件位于deliverables。人工理解、真实分工、其他成员独立复现和课程提交仍由小组完成。

交付核对使用 `python tools/audit_delivery.py --visual-qa-pages 20`，须在实际逐页检查之后运行；它核对原RTL/测试源码、目标输入、负裕量、功耗缺项、复现日志和文档链接，再生成reports/delivery_manifest.json。该清单单独记录本阶段文件哈希及排版检查，不改写旧实验来源。
