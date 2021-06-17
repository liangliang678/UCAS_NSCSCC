# 第五届“龙芯杯”全国大学生计算机系统能力培养大赛

## 版本信息
大赛资源发布包（2021v0.01）

更新日志：
- v0.01（20210601）：提供了大赛预赛需要的参考资料。

## 目录结构

| 目录                          | 功能                             |
| --                            | --                              |
| doc_v0.01/                    | 指导性文档，参考资料              |      
| FPGA_test_v1.00/              | 实验箱校验工具，验证实验箱的正确性 |
| func_test_v0.01/              | 功能测试包                       | 
| perf_test_v0.01/              | 性能测试包                       | 
| system_test_v0.01/            | 系统测试包                       |
| soc_run_os_v0.01/             | 高阶资料包，CPU运行操作系统示例    |


## 性能数据


| date       | modification        | clk | bitcount | bubble_sort | coremark | crc32 | dhrystone | quick_sort | select_sort | sha    | stream_copy | stringsearch | all    |
| :--        | :--                 | :--:| :--:     | :--:        | :--:     | :--:  | :--:      | :--:       | :--:        | :--:   | :--:        | :--:         | :--:   |
| 2021-06-12 | -                   | 50  | 1536d6   | 7b1a26      | 12f3bb6  | b749ea| 2c6470    | 7b1488     | 733be4      | 7a9a30 | 9125e       | 66780e       | 14.343 |
| 2021-06-13 |opt cache FSM        | 50  | c629e    | 59cada      | ce6102   | 7a761a| 20e5f4    | 5294c6     | 437758      | 51aa80 | 6cc46       | 4d4f5e       | 21.083 |
| 2021-06-13 |icache lru           | 50  | c4c3e    | 5977d6      | cd5eb2   | 7a4580| 209b2a    | 51e3fe     | 434300      | 510b76 | 5fc66       | 4cc204       | 21.465 |
| 2021-06-14 |dcache nru & raw opt | 50  | c4c3e    | 5977d6      | cd5ef8   | 7a4580| 209752    | 50d680     | 4342b6      | 510784 | 5f590       | 4cbf2a       | 21.504 |
| 2021-06-14 |uncache buffer       | 50  | c207e    | 5977d6      | c99278   | 75a700| 17eb56    | 50d680     | 4342b6      | 500244 | 5f590       | 3d22c2       | 22.881 |
| 2021-06-14 |if 1st reset         | 50  | c452a    | 59b612      | c9ce2e   | 75cd9e| 18396e    | 516f4c     | 437136      | 507dbe | 688e4       | 3d8cf2       | 22.553 |

## 参考资料

[AXI总线概述](https://blog.csdn.net/bleauchat/article/details/96891619)
