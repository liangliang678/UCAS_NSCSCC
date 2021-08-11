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


| date       | modification               | clk | bitcount | bubble_sort | coremark | crc32 | dhrystone | quick_sort | select_sort | sha    | stream_copy | stringsearch | all    | ipc rate |
| :--        | :--                        | :--:| :--:     | :--:        | :--:     | :--:  | :--:      | :--:       | :--:        | :--:   | :--:        | :--:         | :--:   | :--: |
| 2021-06-12 | -                          | 50  | 1536d6   | 7b1a26      | 12f3bb6  | b749ea| 2c6470    | 7b1488     | 733be4      | 7a9a30 | 9125e       | 66780e       | 14.343 |\|
| 2021-06-13 |opt cache FSM               | 50  | c629e    | 59cada      | ce6102   | 7a761a| 20e5f4    | 5294c6     | 437758      | 51aa80 | 6cc46       | 4d4f5e       | 21.083 |\|
| 2021-06-13 |icache lru                  | 50  | c4c3e    | 5977d6      | cd5eb2   | 7a4580| 209b2a    | 51e3fe     | 434300      | 510b76 | 5fc66       | 4cc204       | 21.465 |\|
| 2021-06-14 |dcache nru & raw opt        | 50  | c4c3e    | 5977d6      | cd5ef8   | 7a4580| 209752    | 50d680     | 4342b6      | 510784 | 5f590       | 4cbf2a       | 21.504 |\|
| 2021-06-14 |uncache buffer              | 50  | c207e    | 5977d6      | c99278   | 75a700| 17eb56    | 50d680     | 4342b6      | 500244 | 5f590       | 3d22c2       | 22.881 |\|
| 2021-06-14 |if 1st reset                | 50   | c452a    | 59b612      | c9ce2e   | 75cd9e| 18396e    | 516f4c     | 437136      | 507dbe | 688e4       | 3d8cf2       | 22.553 |\|
| 2021-06-17 |tlb cache & opt delay       | 70  | b9764    | 4c32fb      | b036ea   | 7b61b7| 141e2e    | 532178     | 3ffe5f      | 4eb5ce | 58930       | 33cccc       | 24.646 |\|
| 2021-06-18 |add ms2ds forward           | 70  | 9ac78    | 461e77      | 9ef97d   | 67705b| 127c51    | 46cb88     | 37fcd4      | 43cdb7 | 518e0       | 2f7ffe       | 27.902 |\|
| 2021-06-18 |add prefetcher              | 70  | 9afe5    | 45f143      | 9b2fcc   | 676acb| 12692f    | 46bbc9     | 37f90a      | 43b656 | 51598       | 2f79bc       | 28.000 |\|
| 2021-06-18 |4way icache                 | 70  | 9ac78    | 45ea55      | 91e9ae   | 676acb| 12683f    | 46b482     | 37f90c      | 43a431 | 51595       | 2f78cd       | 28.183 |\|
| 2021-06-18 |icache plru & prefetcher opt| 70  | 9ac7a    | 45ea54      | 90633a   | 67508e| 1239a7    | 4622a5     | 37d5e8      | 43463a | 49d9d       | 2f2730       | 28.582 |\|
| 2021-06-18 |fix bugs                    | 70  | 9c381    | 461a1a      | 90c794   | 6773c6| 127130    | 46b7ac     | 380426      | 43a71a | 515f3       | 2f79ba       | 28.160 |\|
| 2021-07-30 |dual issue                  | 90  | 5131c    | 2ae904      | 622d7c   | 4af94b| d8978    | 303c81     | 367971      | 2959b0 | 3e3b3       | 1fefab       | 40.901 |\|
| 2021-07-31 |dual issue fix bug; modified mul div rf and forward  | 80  | 6f3a7    | 2efd25      | 73a13f   | 584fc9| fd666    | 388344     | 40837d      | 32eb04 | 468ac       | 24f637       | 34.517 |\|
| 2021-08-1 |dual issue: larger cache line| 90  | 50ed0    | 297476      | 6221a5   | 4e3bdc| d84e9    | 3207b4     | 353179      | 2a8b96 | 3e422       | 1fad2c       | 40.752 |\|
| 2021-08-3 |dual issue: higher frequency| 100  | 4ace2    | 264784      | 5dad1c   | 468ed5| c43a0    | 2ced66     | 2fe20d      | 266ddb | 3ab03       | 1c4681       | 44.557 |\|
| 2021-08-3 |dual issue: exe visit mem   | 100  | 4548c    | 223521      | 54aa20   | 3fa038| b7909    | 293269     | 2cc5ad      | 22a5a1 | 3275e       | 1acf86       | 48.861 | 24.400 |
## 参考资料

1. [AXI总线概述](https://blog.csdn.net/bleauchat/article/details/96891619)
2. 李洪,毛志刚.PLRU替换算法在嵌入式系统cache中的实现[J].微处理机,2010,31(01):16-19
