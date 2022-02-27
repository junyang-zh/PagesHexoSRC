---
title: 写一个 CPU
date: 2021-12-21 15:16:54
tags: CS
---

这是计算机组成课的实验项目，当然，也是学 CS 底层绕不过去的项目。我曾经试过一个 RISC-V 流水线 CPU 的实践，就跟着 Patterson 教授经典的教材 [Computer Organization and Design RISC-V Edition](https://www.elsevier.com/books/computer-organization-and-design-risc-v-edition/patterson/978-0-12-820331-6)，可惜当时动力不是十分充足，做的东西有点烂尾。我觉得到了需要做作业的时候，我大概就有动力了。

可惜 XJTU 的计组不出意料地食古不化，使用 MIPS。无所谓了，反正得写吧。做好的项目已经开源了，如果有小伙伴需要一点参考，那可以看看我是怎么组织这些 Verilog 代码的：

[Github Repository: HeliumCPUv2-MIPS32](https://github.com/James-Hen/HeliumCPUv2-MIPS32)

## 文件目录描述

```plain
.                         # 根目录，包含 Makefile 等文件
|-- common                # 三种 CPU 实现的通用元件
|   |-- dbg_mems          # 仿真用存储器实例
|   |-- ex                # 执行阶段元件，包括 ALU
|   |-- id                # 解码阶段元件，包括解码器、控制器
|   |-- if                # 取值阶段元件
|   |-- mem               # 访存阶段元件
|   `-- wb                # 写回阶段元件
|-- includes              # 宏定义，用于指令集架构描述
|-- multicycle            # 多周期特殊实现
|-- pipeline              # 流水线特殊实现，包括级间寄存与冒险控制
|-- pipeline_bp           # 带分支预测的流水线实现
|-- sim                   # 模拟目录，包括 Testbench 和测试用汇编代码
|   `-- MIPS_sample_src   # 测试用汇编代码目录
`-- single_cycle          # 单周期特殊实现
```

## 准备环境

老师提供的是一个古早版本的 Modelsim，在 Win7 安装才不会出 bug 的那种。说实话，我不想用。有更多的好用或免费的解决方案放在这里呢：

 - [Verilator](https://www.veripool.org/verilator/)
 - [Icarus Verilog](http://iverilog.icarus.com/)
 - [Modelsim](https://eda.sw.siemens.com/en-US/ic/modelsim/)
 - [Vivado](https://china.xilinx.com/products/design-tools/vivado.html)
 - [Quartus](https://www.intel.com/content/www/us/en/software/programmable/quartus-prime/download.html)

笔者使用的是 Icarus Verilog，它比较简单；Verilator 也非常不错，可以使用 C++ 写 Testbench。如果想要 IDE，或者买了赛灵思的板子，那推荐使用 Verilator，也是免费的。

Icarus Verilog 是命令行工具，配合 VSCode 使用很香。VSCode 还有查看波形的插件 [WaveTrace](https://www.wavetrace.io/)，但超过 8 个波形要收费，如果有需求可以使用 [GTKWave](http://gtkwave.sourceforge.net/)。至于怎么安装这些环境，以及怎么跑通我的代码，在 Github 的仓库中有说明。

## 一步一步来

### 小目标

事实上略有点一步登天，但是直接支持多一点指令，能够提前想好奇怪的数据通路，比先实现一个小的指令集再大修大改要优雅。考虑支持下面的指令：

```plain
`R_TYPE: (18)
    `ADD, `ADDU, `SUB, `SUBU,
    `AND, `OR, `XOR, `NOR,
    `SLT, `SLTU, `SLL, `SRA, `SRL,
    `SLLV, `SRAV, `SRLV:
    `JALR, `JR:
`I_TYPE: (22)
    `LB, `LBU, `LH, `LHU, `LW:
    `SB, `SH, `SW:
    `ADDI, `ADDIU, `ANDI, `ORI, `XORI:
    `SLTI, `SLTIU:
    `LUI:
    `BEQ, `BNE:
    `BLEZ, `BGTZ, `BGEZ_BLTZ:
`J_TYPE: (2)
    `J, `JAL:
```

Verilog 的宏就需要使用符号 \` 开头，所以这也是我在 `defines.v` 中说明的方法。

MIPS-32 的指令集分为三种：R 型，I 型和 J 型。R 型指令一般有 `op_code`，`rs`，`rt`，`rd`，`funct` 这么几个有用的字段（具体的请参照指令集手册）。I 型顾名思义，没有 `rd` 和 `funct`，取而代之的是 16 位的立即数 `imm`。至于 `J` 型，除了 `op_code`，剩下的所有位都是目的地址。

现在设计解码器和控制器为时尚早，只是了解一下有什么东西会进来，可以先从简单的开始。

先参照一下别人设计的数据通路图（比如书上的），或者我的：

![SingleCycleDataPath.drawio](/images/WriteCPU/SingleCycleDataPath.drawio.png)

嗯，只是为了看看有什么元件，然后一个一个写。

### 各个模块

#### ALU

事实上，要是不实现乘法，ALU 是最简单的部件，只需要 Case 语句即可，剩下的操作 Verilog 都直接提供了。

#### ALU MUX

要想想为什么设计成这样：ALU 的两个 OP 可以有一些不同的来源，在我这里，它们可以是 PC（为了 JALR, JAL）；可以是立即数；可以是寄存器值。

#### REGFILE

就是很多寄存器存储的地方，顺便解决一下上升沿写入，读出的问题。为了方便，我的读出甚至是组合逻辑。

#### MEM

又称 Memory Access，做的主要工作是处理读字、读半字、读字节的琐事，剩下的交给“内存”就好了。

#### PC

除了每回合自增 4，这个 PC 模块还需要处理取指令，以及跳转。

#### IMEM & DMEM

由于是仿真，不需要接上 FPGA 跑，就和寄存器堆差不多实现就可以了。

#### DECODE & CONTROL

这是最难解决的一部分，也是最能体现设计的一部分，你需要根据指令生成控制信号，耐心些吧。

#### WB

事实上只是一个 MUX，控制把什么写回寄存器堆。

#### COUNTER

是一个计数器，用来产生各个 Stage 的时钟信号。

### 连线

我建议每写一个模块，就把线连出来，这样，写完的时候，线也连好了，几乎就可以测试了！

## 高级的版本

上面只是实现了一个单周期的 CPU，每五个周期做完一条指令。但是做的时候就考虑的流水，所以写模块的时候已经为直接用于流水优化了。

我做了多周期和五级流水，可以前往 Github 看看通路和结果！