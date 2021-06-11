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


<<<<<<< HEAD
| 日期       | 修改        | func       | perf       |
| :--        | :--        | :--:       | :--:       |
| 2021-05-28 | -          | 36216295ns | 38402500ps | 
| 2021-06-06 | 增加了cache | 40871735ns | 26808500ps |
| 2021-06-11 | 修改通路，减少延迟，wns为0.134|40738315ns | -  |
| 2021-06-12 | 切分了preif和if，但是时序似乎变差了|40685515ns| - |
=======
| date       | modification | bitcount | bubble_sort | coremark | crc32 | dhrystone | quick_sort | select_sort | sha    | stream_copy | stringsearch | all    |
| :--        | :--          | :--:     | :--:        | :--:     | :--:  | :--:      | :--:       | :--:        | :--:   | :--:        | :--:         | :--:   |
| 2021-06-11 | -            | 556c7    | 1ec5f8      | 4bcf9b   | 2dd2f3| b18dc     | 1ecd39     | 1cce45      | 1ea656 | 2478e       | 199f8d       | 57.297 |

>>>>>>> d7a5d57c27b21ad1581b12ac28f4c8506dea149b
## 参考资料

[AXI总线概述](https://blog.csdn.net/bleauchat/article/details/96891619)
