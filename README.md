# 芯驿 · 智慧公交站

基于安路 EG4S20BG256 的公交站信息终端。系统在宣传页播放视频、照片或候车音乐，在乘客服务页展示线路和到站演示信息。屏幕通过 HDMI 输出，素材由 SD 卡读取，矩阵键盘和板载按键用于操作。

## 红外切换

红外传感器的数字输出接 P1-8（FPGA C11）。系统上电预热 60 秒。预热结束后，输入先稳定为低至少 100 ms，再稳定为高至少 50 ms，形成一次有效触发。页面在帧边界切到乘客服务。最后一次有效触发后，20 秒内没有新事件则返回宣传。持续高电平只计一次。

手动演示时，矩阵 A 短按或板载 C5 长按约 1 秒可切换宣传与乘客服务。板载 LED 对应 FPGA D6，显示同步后的 C11 电平，高亮低灭。

## 验证记录

| 项目 | 结果 |
| --- | --- |
| 红外与按键控制 | 29 项仿真检查通过，覆盖预热、去抖、重复触发、超时、手动返回和应急优先 |
| 场景显示 | 场景在帧边界提交并传递至像素端的集成仿真通过 |
| 候车音乐与频谱 | 24,000 组 PCM 比对通过，仿真欠载计数为 0，频谱柱高度随 PCM 更新 |
| 布线后时序 | 现有约束下，慢角 setup/hold 裕量 +0.141/+0.047 ns，快角 +0.737/+0.023 ns |
| 实板状态 | 已观察到视频与音乐播放。红外切换逻辑已通过仿真，实板自动触发尚待验收。最近串口诊断中，C11 持续读高，有效触发计数为 0 |

线路与到站时间为演示数据。频谱柱使用音频包络，按该实现展示。

## 工程复现

- 使用 Tang Dynasty 6.2.168116，器件为 EG4S20BG256，顶层为 `station_board_720p`。
- 打开 [TD 工程](project/Station_Board_Keypad_Final.al)。工程克隆到新位置后，先将 AL 根节点的 `Path` 改为本机 `project` 目录的英文绝对路径。
- 板级引脚与时钟约束见 [ADC](project/src/station_keypad_final.adc) 和 [SDC](project/src/station_keypad_final.sdc)。源码快照对应 `Station_MusicFix_PIRDiag_20261102.bit`，工程文件 SHA256 见 [源码清单](source_manifest.json)。

在仓库根目录用 Icarus Verilog 运行红外控制仿真。测试加速毫秒分频，保留 60,000 ms 预热与 20,000 ms 保持参数。

```sh
iverilog -g2012 -s tb -o pir_scene.vvp verification/pir_scene_tb.sv project/src/station_pir_conditioner_module_delay.v project/src/station_control_unit_recovery.v project/src/station_user_control_keypad_v2.v project/src/station_light_control.v
vvp pir_scene.vvp
```

预期输出 `TEST_PASS PIR_SCENES checks=29`。
