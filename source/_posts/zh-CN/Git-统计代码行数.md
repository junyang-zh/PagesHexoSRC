---
title: Git 统计代码行数
date: 2021-12-22 11:24:12
tags: Tech
---

花了一周多，用 Verilog 写完一个 CPU（[Github Repository: HeliumCPUv2-MIPS32](https://github.com/James-Hen/HeliumCPUv2-MIPS32)），想看看自己究竟写了多少行，但是居然没有什么简单的做法。Github 也没有相关统计，怎么办呢？

查了查 Stackoverflow：[Count number of lines in a git repository](https://stackoverflow.com/questions/4822471/count-number-of-lines-in-a-git-repository)，确实给了一些做法。然后我学了学 Bash 的一些用法，采用了下面的方法。

首先，`git ls-files` 会给出仓库里没有 Ignore 的文件，我们把它用管道和 `xargs` 传给 `wc`。`wc` 即 "Word Count"，`-l` 选项可以打印出行数；`xargs` 相当于将管道进来的输入作为命令行参数传给调用的命令。

```bash
git ls-files | xargs wc -l
```

那么就可以得到一些结果

```plain
       6 .gitignore
      21 LICENSE
      43 Makefile
     111 README.md
    1058 assets/MulticycleCounter.png
       0 assets/PipelineCtrlHazard.drawio
     381 assets/PipelineCtrlHazard.drawio.png
       0 assets/PipelineDataHazard.drawio
     376 assets/PipelineDataHazard.drawio.png
       0 assets/PipelineDataPath.drawio
     272 assets/PipelineDataPath.drawio.png
    1512 assets/PipelineHazards.png
    1143 assets/SingleCycleCounter.png
       0 assets/SingleCycleDataPath.drawio
     212 assets/SingleCycleDataPath.drawio.png
      52 common/dbg_mems/dbg_dmem.v
      26 common/dbg_mems/dbg_imem.v
      53 common/dbg_mems/dbg_mem.v
     112 common/ex/alu.v
     348 common/id/control.v
     
     ... # Many lines omitted

    1024 sim/dmem.data
      16 sim/imem.text
      34 sim/testbench.v
      31 single_cycle/counter.v
     155 single_cycle/cpu.v
      41 single_cycle/top.v
    9179 total
```

它几乎把所有的行数都统计进来了，其中也包括一些没忽略的生成的文件（如数据段 `dmem.data`），并不能算写的代码，那么，可以把 `git ls-files` 出来的结果再正则一下，比如只统计 `.v` 文件

```bash
git ls-files | grep ".*\.v" | xargs wc -l
```

输出就干净多了，数的行数也正确

```plain
      52 common/dbg_mems/dbg_dmem.v
      26 common/dbg_mems/dbg_imem.v
      53 common/dbg_mems/dbg_mem.v
     112 common/ex/alu.v
     348 common/id/control.v
     142 common/id/decoder.v
      54 common/id/regfile.v
      38 common/if/pc.v
      86 common/mem/mem.v
      33 common/wb/writeback.v
     168 includes/defines.v
     132 multicycle/counter.v
     162 multicycle/cpu.v
      41 multicycle/top.v
      26 pipeline/control_regs.v
     295 pipeline/cpu.v
      97 pipeline/forward.v
      76 pipeline/hazard.v
      41 pipeline/if.v
      40 pipeline/top.v
      26 pipeline_bp/control_regs.v
     318 pipeline_bp/cpu.v
      97 pipeline_bp/forward.v
     118 pipeline_bp/hazard.v
      97 pipeline_bp/if.v
      40 pipeline_bp/top.v
      34 sim/testbench.v
      31 single_cycle/counter.v
     155 single_cycle/cpu.v
      41 single_cycle/top.v
    2979 total
```

我在 MacOS 得到的如上结果，Linux 的各发行版几乎都行，Windows 就乖乖使用 WSL 吧。
