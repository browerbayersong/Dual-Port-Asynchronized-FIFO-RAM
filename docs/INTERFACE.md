# 单通道接口与时序

当前模块为 rtl/async_fifo.v 中的 async_fifo，设计使用 Verilog，测试平台使用 SystemVerilog。

## 参数

| 参数 | 默认值 | 含义 |
| --- | --- | --- |
| DATA_WIDTH | 32 | 数据字位宽 |
| ADDR_WIDTH | 8 | RAM 地址位数，深度为 2^ADDR_WIDTH |
| SYNC_STAGES | 2 | 两个方向指针同步级数，至少 2 |
| COUNT_WIDTH | 32 | 六个本地饱和计数器位宽 |
| AF_ASSERT / AF_CLEAR | 224 / 224 | 水位 >=AF_ASSERT 置位，<AF_CLEAR 撤销 |
| AE_ASSERT / AE_CLEAR | 32 / 32 | 水位 <=AE_ASSERT 置位，>AE_CLEAR 撤销 |

DATA_WIDTH、ADDR_WIDTH、COUNT_WIDTH 至少为 1。0<=AF_CLEAR<=AF_ASSERT<=DEPTH，0<=AE_ASSERT<=AE_CLEAR<=DEPTH。AF_CLEAR=0 会使已置位的 almost_full 无法通过非负水位撤销，正常使用建议取正数。当前自动回归使用 256×32，计数位宽为 32 或测试专用的 4。

## 端口

| 方向 | 端口 | 宽度/所属域 | 说明 |
| --- | --- | --- | --- |
| 输入 | rst_n | 1，共同复位 | 低有效，两域各 2 拍同步释放 |
| 输入 | wr_clk、wr_en、wr_data | 1、1、DATA_WIDTH，写域 | 写时钟、请求、数据 |
| 输出 | full、almost_full | 各 1，写域 | 满及几乎满 |
| 输出 | wr_level | ADDR_WIDTH+1，写域 | 注册水位估计 |
| 输出 | wr_rst_done | 1，写域 | 本地复位同步释放状态 |
| 输出 | write_count、overflow_count | 各 COUNT_WIDTH，写域 | 成功写、满时写尝试 |
| 输入 | rd_clk、rd_en、rd_ready | 各 1，读域 | 读时钟、请求、响应接收能力 |
| 输出 | rd_data、rd_data_valid | DATA_WIDTH、1，读域 | 同步读响应 |
| 输出 | empty、almost_empty | 各 1，读域 | 空及几乎空 |
| 输出 | rd_level | ADDR_WIDTH+1，读域 | 注册水位估计 |
| 输出 | rd_rst_done | 1，读域 | 本地复位同步释放状态 |
| 输出 | read_count、underflow_count | 各 COUNT_WIDTH，读域 | 成功读、空时有效读尝试 |
| 输出 | backpressure_count、backpressure_cycles | 各 COUNT_WIDTH，读域 | 背压事件与周期 |

统计输出保持各自的时钟域属性，尚未经过统一监控跨域采样；不能逐位直接同步正在变化的二进制统计总线。

## 接受、响应与复位

- 写上升沿 wr_rst_done && wr_en && !full 才写 RAM、推进指针并增加成功写计数。
- 读上升沿 rd_rst_done && rd_en && rd_ready && !empty 才读取并推进指针；边沿后 rd_data 更新，rd_data_valid=1。
- 下一读边沿没有接受请求时 rd_data 保持、rd_data_valid=0。最后一个字有效时可以同时 empty=1。
- rd_ready 表示下游可接收这次请求的响应；该接口没有标准流式接口的弹性缓冲。
- 外部等待两域复位完成，并经过本地域有效边沿后再开始请求。

overflow 每个 wr_en && full 的写边沿加一；underflow 每个 rd_en && rd_ready && empty 的读边沿加一。stall=rd_en && !empty && !rd_ready，其 0→1 累计一次事件，每个 stall 周期累计一个持续周期。全部计数饱和于全 1，复位置零。

空满与阈值因指针同步而保守延迟。写侧水位倾向高估，读侧倾向低估；它们不是全局瞬时精确水位。

RAM 不清零。共同复位清空逻辑队列并将读输出清零，旧 RAM 内容被 empty 和指针屏蔽。运行中单侧独立复位不在当前接口范围内。
