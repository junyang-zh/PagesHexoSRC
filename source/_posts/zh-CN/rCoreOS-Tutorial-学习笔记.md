---
title: rCoreOS Tutorial 学习笔记
date: 2023-03-07 16:16:13
tags: CS
---

由于需要做操作系统的工作，但是只上了比较没用的西交理论课，于是我不会 OS 开发（暂时）。组里推荐了清华课用的 rCoreOS，于是自学并尝试做一些作业。

主要跟着 rCoreOS Tutorial 的在线书学习，如果有一定 CS 理论知识基础和 Rust 基础，学起来应该很轻松。如果会用 C 做内核开发但是不会 Rust，这本书也是不错的 Rust 内核（从零）开发的教程。还有就是，本书跟 Linux 没什么关系，不需要很会。

Repo: [rCore-Tutorial-v3](https://github.com/rcore-os/rCore-Tutorial-v3)

Book: [rCore-Tutorial-Book-v3](http://rcore-os.cn/rCore-Tutorial-Book-v3/index.html)

在线书已经写的比较新手友好了，参考答案也存在，但是不全，并且实验也有一些不大的坑，或者书和代码有出入。我觉得写这篇文章可以帮助你更快搞定一些没详细写到的内容，于是分享此笔记。先看书，要做实验的时候可以看看这个。

我在 2023 年二月份进行的学习，目前这个课程的材料仍在不断更新，所以以下内容也仅供参考。

## 第零章

第零章如果理论学过了大可不细看，仅搭环境即可。

我用的老师的 x86 Ubuntu 服务器。VSCode SSH 连接 Remote 开发。编译运行的时候直接用 Docker 环境，省去很多麻烦。本地也可以复用这套环境。Clone 仓库后进入目录即可 Make Docker 镜像。

这个 Docker 镜像**只**包括了运行需要的 QEMU 7.x.x，编译需要的 Rust 和 C 工具链。课程的框架代码不在镜像里。镜像里面也没有 RISCV GDB，所以需要自行下载，并修改一下 Dockerfile 加入 GDB，再构建。

```bash
# Download the rCoreOS repository
git clone https://github.com/rcore-os/rCore-Tutorial-v3
cd rCore-Tutorial-v3
# Download RISCV toolchain
wget https://static.dev.sifive.com/dev-tools/freedom-tools/v2020.12/riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-linux-ubuntu14.tar.gz
```

接下来修改 Dockerfile。

```dockerfile
# 3.
# ...
# 4. Download and add RISCV Toolchain
ARG RV_TOOLCHAIN=riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-linux-ubuntu14
WORKDIR /usr/local/
ADD ${RV_TOOLCHAIN}.tar.gz .
RUN cp -r ${RV_TOOLCHAIN}/* . && rm -r ${RV_TOOLCHAIN}
WORKDIR ${HOME}
```

或者可以直接在 Dockerfile 里下载解压。

如果是 M1 的 Mac，需要自己编译 aarch64 的 Toolchain。（我失败了，QEMU 还是不能正确运行）

```dockerfile
# 4. Download and install rv toolchain
WORKDIR ${HOME}
RUN git clone https://github.com/riscv/riscv-gnu-toolchain
WORKDIR ${HOME}/riscv-gnu-toolchain
RUN ./configure --prefix=/usr/local && \
    make linux
WORKDIR ${HOME}
RUN rm -rf riscv-gnu-toolchain
```

可以 Dockerfile 配置一下 crates.io 的换源。

```dockerfile
# 2.3. Rust src mirror
RUN CARGO_CONF=$CARGO_HOME'/config'; \
    BASHRC='/root/.bashrc' \
    && echo 'export RUSTUP_DIST_SERVER=https://rsproxy.cn' >> $BASHRC \
    && echo 'export RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup' >> $BASHRC \
    && touch $CARGO_CONF \
    && echo '[source.crates-io]' > $CARGO_CONF \
    && echo "replace-with = 'rsproxy-sparse'" >> $CARGO_CONF \
    && echo '[source.rsproxy]' >> $CARGO_CONF \
    && echo 'registry = "https://rsproxy.cn/crates.io-index"' >> $CARGO_CONF \
    && echo '[source.rsproxy-sparse]' >> $CARGO_CONF \
    && echo 'registry = "sparse+https://rsproxy.cn/index/"' >> $CARGO_CONF \
    && echo '[registries.rsproxy]' >> $CARGO_CONF \
    && echo 'index = "https://rsproxy.cn/crates.io-index"' >> $CARGO_CONF \
    && echo '[net]' >> $CARGO_CONF \
    && echo 'git-fetch-with-cli = true' >> $CARGO_CONF
```

我构建镜像的时候 QEMU 官方下载炸了，我用的 [https://fossies.org/linux/misc/qemu-7.2.0.tar.xz](https://fossies.org/linux/misc/qemu-7.2.0.tar.xz)。

Dockerfile 里还有一句 `cargo install cargo-binutils -vers ~0.2 && \`，会强制版本，可以删掉。如果不删掉，Rust 版本会变成老版本。

改完然后构建镜像。

```bash
sudo make build_docker
```

仓库根目录自带的 Makefile 写了使用 Docker 镜像的命令，即在根目录用命令 `sudo make docker` 运行镜像。但是我这里在 Make 时没有 `$PWD` 环境变量，所以把 Makefile 改成下面这样就能跑了。这个问题在 ch2 及以后的有些分支修掉了，但是有可能 `DOCKER_NAME` 不对，需要注意。

```makefile
docker:
	docker run --rm -it -v `pwd`:/mnt -w /mnt ${DOCKER_NAME} bash
```

这条命令会将 Docker 环境里 `mnt` 目录和仓库根目录做映射，这样能持久化你的改动，不用让容器一直跑或者担心保存的问题。

调试的时候需要在容器内使用多个命令行，我不喜欢用 tmux（~~VSCode 用户是这样的~~），所以可以打开另一个命令行再开启 Docker 的另一个 bash 进程。

```bash
sudo docker exec -it ${CONTAINER_NAME} bash
```

这里的 `CONTAINER_NAME` 可以用 `sudo docker ps` 发现，然后换上去。验证这个搞法，可以试试在同一个容器的两个 Bash 里，`cd os`，一个跑 `make gdbserver`，一个跑 `make gdbclient`。

## 第一章

### 内核第一条指令（实践篇）

如果搭环境的时候能调试了，那么确实可以看见 QEMU 启动固件的代码，位于 `0x1000`。我的结果和书上不太一致，但差不多，应该是 QEMU 更新了。

```gdb
(gdb) x/10i $pc
=> 0x1000:      auipc   t0,0x0
   0x1004:      addi    a2,t0,40
   0x1008:      csrr    a0,mhartid
   0x100c:      ld      a1,32(t0)
   0x1010:      ld      t0,24(t0)
   0x1014:      jr      t0
   0x1018:      unimp
   0x101a:      0x8000
   0x101c:      unimp
   0x101e:      unimp
```

作为有兴趣的同学，会知道 `auipc t0,0x0` 将 PC 的值（加零后）放入通用寄存器 t0。`mhartid` 寄存器表示运行当前代码的硬件线程（hart）的 ID。`csrr` 是伪指令，专门用来读 m 开头的特权寄存器。`0x100c` 处的 `ld` 指令做 `a1 <- $(t0 + 32)`，并且 `t0 + 32 = 0x1000 + 0x20 = 0x1020`。

看看 `0x1020` 是啥。

```gdb
(gdb) x/1xw 0x1020
0x1020: 0x87000000
```

那同理，对于 `0x1010` 处的 `ld` 指令，`t0 + 24 = 0x1018`。

```gdb
(gdb) x/1xw 0x1018
0x1018: 0x80000000
```

嗯，虽然新加进来的东西不懂，但是 `0x80000000` 是 bootloader 初始地址，理解了。

### 编程练习

> 3. \*\* 实现一个基于rcore/ucore tutorial的应用程序C，用sleep系统调用睡眠5秒（in rcore/ucore tutorial v3: Branch ch1）

**这题别看我的答案，审题错误，一坨答辩。**

这个练习没有答案，但是若要实现得好感觉比第二题还难，因为必须考虑 Trap 了。当然，死循环然后检查时间也不是不行吧，毕竟独占 CPU。

若是读一下后面的实现，会发现 `sys_sleep` 系统调用没有直接用硬件 timer，而是用的内核的计时器堆。那么我就尝试实现一下用硬件 timer 的 `ksleep` 好了。原理是先 `sbi::set_timer()`，再死循环等 Trap。

先实现 `set_timer()`。

```rust
// sbi.rs

// ...
const SBI_SET_TIMER: usize = 0;
// ...

/// use sbi call to set a timer
pub fn set_timer(timer: usize) {
    sbi_call(SBI_SET_TIMER, timer, 0, 0);
}
```

接下来要让内核能处理 Trap，在 ch2 分支才会实现 Trap 处理，需要把 `mod trap` 拷过来，并增加 SupervisorTimer 的处理。为了理解这部分的内容，需要先学习第二章。

```rust
// trap/mod.rs

// ...
use riscv::register::{
    mtvec::TrapMode,
    scause::{self, Exception, Trap, Interrupt},
    stval, stvec, sstatus, sie
};
// ...
pub fn init() {
    extern "C" {
        fn __alltraps();
    }
    unsafe {
        stvec::write(__alltraps as usize, TrapMode::Direct);
        sstatus::set_sie();
        sie::set_stimer();
    }
}
// ...
pub fn trap_handler(cx: &mut TrapContext) -> &mut TrapContext {
// ...
        Trap::Interrupt(Interrupt::SupervisorTimer) => {
            println!("[kernel] Got timer interruption.");
            unsafe { TIMER_TRAPPED = true; }
        }
// ...
}
```

最后实现 `ksleep()`。

```rust
// main.rs

use riscv::register::{ time };
const CLOCK_FREQ: usize = 12500000;
static mut TIMER_TRAPPED: bool = false;
use crate::sbi::set_timer;
/// the kernel sleep function, t in milliseconds
fn ksleep(t: usize) {
    let cur = time::read();
    let fut = cur + CLOCK_FREQ * t / 1000;
    set_timer(fut);
    println!("[kernel] current time {}, timer at {}.", cur, fut);
    println!("[kernel] timer set in sleep(), busy looping.");
    unsafe {
        while !TIMER_TRAPPED {}
        TIMER_TRAPPED = false;
    }
}
```

完事了在 `rust_main()` 调用下试试就好了。记得先调用 `trap::init()`。最后还没调出来，可以 Trap 但无法正确返回，先进行到下一章好了。

## 第二章

### 实验练习

> ch2 中，我们实现了第一个系统调用 `sys_write`，这使得我们可以在用户态输出信息。但是 os 在提供服务的同时，还有保护 os 本身以及其他用户程序不受错误或者恶意程序破坏的功能。
>
> 由于还没有实现虚拟内存，我们可以在用户程序中指定一个属于其他程序字符串，并将它输出，这显然是不合理的，因此我们要对 sys_write 做检查：
>
> - sys_write 仅能输出位于程序本身内存空间内的数据，否则报错。

测试样例在 `user/src/bin` 下，有两个 test。这两个 test 会被编译成二进制然后载入进批处理系统里。需要注意的是，输入不支持的 fd 需要返回 -1 而不是 panic，不然过不了。

不太难（~~虽然我有一段时间搞不清楚 APP 加载到哪个地址去了~~），主要代码如下。

```rust
// src/syscall/fs.rs

use crate::batch::{ USER_STACK, USER_STACK_SIZE, APP_BASE_ADDRESS, APP_SIZE_LIMIT };

pub fn sys_write(fd: usize, buf: *const u8, len: usize) -> isize {
    // checking the sanity of the buffer
    let mut good: bool = false;
    unsafe {
        // if in stack
        if USER_STACK.data.as_ptr() <= buf && buf.add(len) <=
      			USER_STACK.data.as_ptr().add(USER_STACK_SIZE) {
            good = true;
        }
        // if in allocated static app memory (.data etc)
        else if APP_BASE_ADDRESS as *const u8 <= buf
            && buf.add(len) <=
      			(APP_BASE_ADDRESS + APP_SIZE_LIMIT) as *const u8 {
            good = true;
        }
    }
    if !good {
        return -1;
    }
    match fd {
    // ...
```

还需要把 `src/batch.rs` 里该 pub 的变量 pub 了，然后再改下用户栈大小到 `0x1000`。

运行 `make run TEST=1` 正确的输出应该是这样。

```plain
[kernel] Hello, world!
[kernel] num_app = 2
[kernel] app_0 [0x8020a020, 0x8020f558)
[kernel] app_1 [0x8020f558, 0x80214b60)
[kernel] Loading app_0
Test write0 OK!
[kernel] Application exited with code 0
[kernel] Loading app_1
string from data section
strinstring from stack section
strin
Test write1 OK!
[kernel] Application exited with code 0
```

## 第三章

### 课后练习

一、二、四题都跟实验差不多，于是不想做了。我倒是对浮点实现、内核态中断和内核任务有点兴趣，先挖坑。

#### 3. 浮点扩展

先扩展 `TaskContext`，参考 [RISCV Calling Convention](https://riscv.org/wp-content/uploads/2015/01/riscv-calling.pdf)，需要保存的浮点寄存器是 `fs0-fs11`，和整数类似，那么先在 `TaskContext` 留出对应空间。

```rust
// task/context.rs

/// Task Context
#[derive(Copy, Clone)]
#[repr(C)]
pub struct TaskContext {
    /// return address ( e.g. __restore ) of __switch ASM function
    ra: usize,
    /// kernel stack pointer of app
    sp: usize,
    /// callee saved registers:  s 0..11
    s: [usize; 12],
    /// callee saved fp registers: fs 0-11
    fs: [fsize; 12]
}
```

那个 `fsize` 不是 Rust 标准里的东西，是我在 `config.rs` 里写的，因为 RISCV 里所有浮点寄存器的长度取决于扩展，RV64F 的话对应 `f32`，RV64D 对应 `f64`。

再尝试修改 `switch.S`。

```assembly
.attribute arch, "rv64gc"
# ...
.macro SAVE_FSN n
    fsd fs\n, (\n+14)*8(a0)
.endm
.macro LOAD_FSN n
    fld fs\n, (\n+14)*8(a1)
.endm
# ...
# save ra & s0~s11 of current execution
    sd ra, 0(a0)
    .set n, 0
    .rept 12
        SAVE_SN %n
        SAVE_FSN %n
        .set n, n + 1
    .endr
    # restore ra & s0~s11 of next execution
    ld ra, 0(a1)
    .set n, 0
    .rept 12
        LOAD_SN %n
        LOAD_FSN %n
        .set n, n + 1
    .endr
# ...
```

第一行不加的话汇编器会报错，不知为什么不是 `"rv64d"`，但是这样就好了。

`TrapContext` 也差不多，只不过需要保存 `f0-f31`，不再赘述了。

到这里还是会出问题，直接抛了 Bad Instruction。

```plain
[kernel] Hello, world!
[kernel] PageFault in application, bad addr = 0xfffffffffffffef8, bad instruction = 0x80200536, kernel killed it.
```

到 GDB 里调出来抛异常的点。

```gdb
(gdb) x/5i $pc
=> 0x802003ec <__switch+8>:     sd      s0,16(a0)
   0x802003ee <__switch+10>:    fsd     fs0,112(a0)
   0x802003f0 <__switch+12>:    sd      s1,24(a0)
   0x802003f2 <__switch+14>:    fsd     fs1,120(a0)
   0x802003f4 <__switch+16>:    sd      s2,32(a0)
```

确切位置是在 `0x802003ee` 的 `fsd` 指令。确认这些指令完全正确没问题，那问题在哪。

不得不借鉴下 Linux 源码怎么处理的了，看到 [arch/riscv/kernel/process.c](https://github.com/torvalds/linux/blob/89f5349e0673322857bd432fa23113af56673739/arch/riscv/kernel/process.c#L114) 我悟了，需要设置 `sstatus` 寄存器 `SR_FS_INITIAL` 位才能正常使用浮点指令，于是乎在合适的位置加入

```rust
unsafe { sstatus::set_fs(sstatus::FS::Initial); }
```

即可，由于干作业越糙越好，就直接在 `main` 搞初始化的时候开启了。

测试的话，直接让第一个程序算 $1.0001^{(10^6)}$，它会最后一个完成，然后算出来一个精度烂掉的正确结果。

```plain
power_3 [980000/1000000]
power_3 [990000/1000000]
power_3 [1000000/1000000]
1.0001^1000000 = 26747109931126675000000000000000000000000000
Test power_3 OK!
[kernel] Application exited with code 0
Test sleep OK!
[kernel] Application exited with code 0
All applications completed!
```

### 实验练习

实验需要实现系统调用 `sys_task_info`。实现没什么弯弯绕的，就是记录数据然后给出数据即可，难度不高。

#### 记录数据

记录数据可以在 `TaskControllBlock` 中进行，我增加的字段如下。

```rust
--- a/os/src/task/task.rs
+++ b/os/src/task/task.rs

 #[derive(Copy, Clone)]
 pub struct TaskControlBlock {
     pub task_status: TaskStatus,
     pub task_cx: TaskContext,
+    pub call_cnt: usize,
+    pub call: [SyscallInfo; MAX_SYSCALL_NUM],
+    // the timestamp in ms of the start time if running
+    pub last_start: usize,
+    // total run time in ms
+    pub run_time: usize
 }
```

两个 call 相关的字段记录系统调用和总数量，由于没有内核堆，所以就是个数组。最大系统调用数量写到 `config.rs` 里了。`last_start` 字段记录进入运行状态的时刻，用于在进入挂起或退出状态时统计时间。为了上面的代码，需要增加一些初始化，编译器会教你怎么改。

记录系统调用的接口放在 `TaskManager` 里。当 `syscall` 函数被调用的时候就调用这个方法即可。

```rust
// src/task/mod.rs
impl TaskManager {
// ...
    /// Recording sys_task_info, called when syscall called
    pub fn record_current_syscall(&self, syscall_id: usize) {
        let mut inner = self.inner.exclusive_access();
        let current = inner.current_task;
        let cur_task = &mut inner.tasks[current];
        for ci in &mut cur_task.call {
            if ci.id == 0 {
                ci.id = syscall_id;
                ci.times = 1;
                break;
            }
            else {
                ci.times += 1;
                break;
            }
        }
    }
}
```

记录时间，则在 `run_first_task`，`run_next_task` 加入这句话。

```rust
next_task.last_start = get_time_ms();
```

并在 `mark_current_suspended`，`mark_current_exited` 加入这句话。

```rust
cur_task.run_time += get_time_ms() - cur_task.last_start;
```

注意在 `run_next_task` 里不要增加 `run_time`，不然就重复了。

#### 给出数据

给出数据即实现系统调用。首先还是先把接口放 `TaskManager` 里，然后实现 `syscall` 的时候调用 `TaskManager` 的方法。

```rust
// os/src/task/mod.rs
impl TaskManager {
// ...
		/// Implementation of sys_task_info
    pub fn get_task_info(&self, id: usize) -> Option<TaskInfo> {
        if id >= self.num_app {
            return None;
        }
        let tm = self.inner.exclusive_access();
        let ts = TaskInfo {
            id: id,
            status: tm.tasks[id].task_status,
            call: tm.tasks[id].call,
            time: tm.tasks[id].run_time
        };
        Some(ts)
    }
}
```

这里用了 `core::option::Option` 来避免在代码里传入指针获得结果，只有在接口这么干。更 “Rusty”。

在内核中的接口如下。

```rust
// os/src/syscall/process.rs
/// get info of a task
pub fn sys_task_info(id: usize, ts: *mut TaskInfo) -> isize {
    let Some(res) = TASK_MANAGER.get_task_info(id) else { return -1 };
    unsafe { *ts = res; }
    0
}
// os/src/syscall/mod.rs
/// handle syscall exception with `syscall_id` and other arguments
pub fn syscall(syscall_id: usize, args: [usize; 3]) -> isize {
    TASK_MANAGER.record_current_syscall(syscall_id);
    match syscall_id {
        SYSCALL_WRITE => sys_write(args[0], args[1] as *const u8, args[2]),
        SYSCALL_EXIT => sys_exit(args[0] as i32),
        SYSCALL_YIELD => sys_yield(),
        SYSCALL_GET_TIME => sys_get_time(),
        SYSCALL_TASK_INFO => sys_task_info(args[0], args[1] as *mut TaskInfo),
        _ => panic!("Unsupported syscall_id: {}", syscall_id),
    }
}
```

`sys_task_info` 实现用了一个 Rust `let_else` 的不稳定特性，但是好用，以后会稳定的。现在用需要打开 `#[feature(let_else)]`。

在用户程序库中的接口如下。

```rust
// user/src/syscall.rs
pub fn sys_task_info(id: usize, ts: *mut TaskInfo) -> isize {
    syscall(SYSCALL_TASK_INFO, [id, ts as usize, 0])
}
// user/src/lib.rs
pub fn task_info(id: usize, ts: *mut TaskInfo) -> isize {
    sys_task_info(id, ts)
}
```

我还省略了不少“过编译”的代码，包括各种 `use`，各种没声明过的 struct 和初始化，以及各种语言修饰，编译器都会教你怎么弄，Rust 就好在这里。

#### 测试与结果

我在第三个测测试快要完成时查询所有 task 的信息并全部输出，代码如下。

```rust
// user/src/bin/03sleep.rs

    for id in 0..5 {
        let mut ti = TaskInfo { id: 0, status: TaskStatus::UnInit, call: [SyscallInfo {id: 0, times: 0}; 10], time: 0 };
        if task_info(id, &mut ti) >= 0 {
            println!("Info of task {} is:\n    {:?}", id, ti);
        }
        else {
            println!("Task info query for task {} failed!", id);
        }
    }
```

这里输出需要各种 struct 实现 Debug Trait，加个修饰就好了。另外没有去实现 `TaskInfo` 默认初始化，所以比较丑，摸了。输出如下，省略了一些为空的 `call` 项。

```plain
Info of task 0 is:
    TaskInfo { id: 0, status: Exited, call: [SyscallInfo { id: 64, times: 110 }, SyscallInfo { id: 0, times: 0 }, SyscallInfo { id: 0, times: 0 }, SyscallInfo { id: 0, times: 0 }, ...], time: 6 }
Info of task 1 is:
    TaskInfo { id: 1, status: Exited, call: [SyscallInfo { id: 64, times: 80 }, ...], time: 5 }
Info of task 2 is:
    TaskInfo { id: 2, status: Exited, call: [SyscallInfo { id: 64, times: 90 }, ...], time: 4 }
Info of task 3 is:
    TaskInfo { id: 3, status: Running, call: [SyscallInfo { id: 169, times: 1635571 }, ...], time: 2726 }
Task info query for task 4 failed!
```

都挺合理，但是记录毫秒显然有累计误差，建议记录时钟，能准确不少。

## 第四章

### 课后练习

咕咕咕

### 实践作业

#### 重写 sys_get_time

原来的还是能用的，但是改了个签名就不能用了。实际上，所有把结果写回用户地址空间内存以及读用户地址空间内存的方法都要重写。还很麻烦。并且教程里对 `sys_write` 的实现也是有 bug 的，UTF-8 是变长编码，buffer 跨页并且非英文字符跨页了就可能会炸。不过好在问题也不太大。

还有就是，ch4-lab 分支编译不了，因为引用的 rCore 版本的 riscv crate 炸了。那就写点代码装装样子。（这个问题我在做下一章作业的时候自己修了，看下一章实践作业）

```rust
pub fn sys_get_time(_ts: *mut TimeVal, _tz: usize) -> isize {
    let us = get_time_us();
  	let result = TimeVal {
        sec: us / 1_000_000,
        usec: us % 1_000_000,
    };
  	let sz = size_of::<TimeVal>();
    let buffers = translated_byte_buffer(current_user_token(), _ts, sz);
  	match buffers.len() {
        1 => {
            unsafe {
                *(buffers[0].as_ptr() as *mut TimeVal) = result;
            }
        },
      	2 => {
			      // crazy enough
          	unsafe {
			          let rs = std::slice::from_raw_parts(
			              &result as *const TimeVal as *const u8, sz);
              	let l0 = buffers[0].len();
              	buffers[0].copy_from_slice(&rs[0..l0]);
              	buffers[1].copy_from_slice(&rs[l0..sz]);
            }
        },
      	_ => { panic!("size_of(TimeVal) larger than a page!"); }
    };
    0
}
```

在 [Rust Playground](https://play.rust-lang.org/?version=stable&mode=debug&edition=2021&gist=918534834ee594b6619c3ebb0e590a3c) 测试了一下，没问题。其实也可以改成循环然后支持返回 buffer 跨很多页的情况，但是这种情况也太恐怖了。

#### mmap 和 munmap

实现这一对调用最难顶的问题是：

1. 如果 `mmap` 了两个相邻的段，应该把这两个段合并为一个段；
2. 如果地址得当，一次 `munmap` 可以取消多次 `mmap` 形成的映射；
3. `munmap` 可以只取消一部分映射，剩下头尾仍需要映射。

因为我懒死了，所以假设上面的问题都不存在好了，能过测试用例谢天谢地。可以假设如果操作得当，`mmap` 和 `munmap` 是一一对应的。如果没有这样的假设，那就不能用 `Vec` 装 `MapArea` 了，得用 `BTreeMap`。

继续写点代码装装样子。`MemorySet` 里需要实现一个检查是否已映射的函数，和根据范围取消包含它的映射的函数。

```rust
// mm/memory_set.rs
impl MemorySet {
    #[allow(unused)]
    pub fn range_has_mapped(&self, start: VirtPageNum, end: VirtPageNum) -> bool {
        // check overlap
        self.areas.iter_mut()
            .find(|area| area.vpn_range.get_start() < end &&
                        start < area.vpn_range.get_end())
        != None
    }
    #[allow(unused)]
    /// Assume that there are no adjacent areas
    pub fn unmap_area_by_range(&mut self, start: VirtPageNum, end: VirtPageNum)
  			-> bool
    {
        // check containing
        let Some(pos) = self.areas.iter_mut()
            .position(|area| area.vpn_range.get_start() <= start &&
                        end <= area.vpn_range.get_end())
        {
            self.areas[pos].unmap(self.page_table);
            self.areas.remove(pos);
            true
        }
        else {
            false
        }
    }
}
```

让 `TaskManager` 修改当前任务的 `MemorySet`，调用当前任务 `TaskControllBlock` 中如下的函数即可。

```rust
impl TaskControlBlock {
    /// map a new area
    pub fn map_program_area(&mut self, 
        start: VirtPageNum, end: VirtPageNum, prot: usize) -> bool {
        if self.memory_set.range_has_mapped(start, end) ||
            prot & !0x7 != 0 || prot & 0x7 = 0 {
            return false
        }
        let mut permission = MapPermission::U;
        if (prot & 0x1) { permission |= MapPermission::R; }
        if (prot & 0x2) { permission |= MapPermission::W; }
        if (prot & 0x4) { permission |= MapPermission::X; }
        self.memory_set.push(
          MapArea::new(start_va.into(), end_va.into(),
            MapType::Framed, permission),
          None);
        true
    }
    /// unmap a area
    pub fn unmap_program_area(&mut self, start: VirtPageNum, end: VirtPageNum)
        -> bool
    {
        self.memory_set.unmap_area_by_range(start, end)
    }
}
```

剩下的都是实现接口的代码，没必要列出来了。（~~实际上是没写~~）

## 第五章

### 实验练习 1

```rust
pub fn spawn(path: *const u8) -> isize {
    match fork() {
        -1 => { -1 },
        0 => { exec(path) },
        pid => { pid }
    }
}
```

开个玩笑，开个玩笑。（~~但是以前的 `posix_spawn` 就是这么搞的~~）

和上一章一样，这一章 `lab` 分支的 riscv crate 也出问题了，不得不尝试修一下了。首先升级 Rust 版本，修改目录下 `rust-toolchain` 文件。然后在 `cargo.toml` 里修改 riscv crate 为官方版本 `0.10.1`。根据编译错误修代码。

```rust
// trap/context.rs

// sstatus.set_spp(SPP::User); not working, make it dirty
unsafe {
    *(&mut sstatus as *mut Sstatus as *mut usize) &= !(1 << 8);
}
```

然后实现 `spawn`。

```rust
// task/task.rs
// impl TaskControlBlock
pub fn spawn(self: &Arc<TaskControlBlock>, elf_data: &[u8]) -> Arc<TaskControlBlock> {
    // alloc a pid and a kernel stack in kernel space
    let pid_handle = pid_alloc();
    let kernel_stack = KernelStack::new(&pid_handle);
    let kernel_stack_top = kernel_stack.get_top();
    // memory_set with elf program headers/trampoline/trap context/user stack
    let (memory_set, user_sp, entry_point) = MemorySet::from_elf(elf_data);
    let trap_cx_ppn = memory_set
    .translate(VirtAddr::from(TRAP_CONTEXT).into())
    .unwrap()
    .ppn();
    // modify trap context
    *trap_cx_ppn.get_mut() = TrapContext::app_init_context(
        entry_point,
        user_sp,
        KERNEL_SPACE.exclusive_access().token(),
        kernel_stack_top,
        trap_handler as usize,
    );
    // ---- access parent PCB exclusively
    let mut parent_inner = self.inner_exclusive_access();
    let task_control_block = Arc::new(TaskControlBlock {
        pid: pid_handle,
        kernel_stack,
        inner: unsafe { UPSafeCell::new(TaskControlBlockInner {
            trap_cx_ppn,
            base_size: parent_inner.base_size,
            task_cx: TaskContext::goto_trap_return(kernel_stack_top),
            task_status: TaskStatus::Ready,
            memory_set,
            parent: Some(Arc::downgrade(self)),
            children: Vec::new(),
            exit_code: 0,
        })},
    });
    // add child
    parent_inner.children.push(task_control_block.clone());
    // return
    task_control_block
    // ---- release parent PCB automatically
    // **** release children PCB automatically
}
```

实现接口。

```rust
// syscall/process.rs
pub fn sys_spawn(path: *const u8) -> isize {
    let token = current_user_token();
    let path = translated_str(token, path);
    let current_task = current_task().unwrap();
    let new_task;
    if let Some(data) = get_app_data_by_name(path.as_str()) {
        new_task = current_task.spawn(data);
    } else {
        return -1;
    }
    let new_pid = new_task.pid.0;
    // we do not have to modify trap context of the new task
    // add new task to scheduler
    add_task(new_task);
    new_pid as isize
}
```

结果如下。

```plain
>> test_spawn1
new child 3
Test wait OK!
Test waitpid OK!
Shell: Process 2 exited with code 0
>> test_spawn0
new child 3
new child 4
...
new child 30
Test getpid OK! pid = 3
Test getpid OK! pid = 4
...
Test getpid OK! pid = 30
Test getpid OK! pid = 31
new child 31
...
new child 34
Test getpid OK! pid = 10
Test getpid OK! pid = 32
Test getpid OK! pid = 33
Test getpid OK! pid = 34
new child 35
...
new child 42
Test getpid OK! pid = 35
...
Test getpid OK! pid = 42
Test spawn0 OK!
Shell: Process 2 exited with code 0
```

### 实验练习 2

在 `TaskControlBlockInner` 加两个字段，`prio: isize` 和 `stride: usize`。实现接口。

```rust
// syscall/process.rs
pub fn sys_set_priority(prio: isize) -> isize {
    if prio < 2 {
        return -1;
    }
    let current_task = current_task().unwrap();
    let mut current_task_inner = current_task.inner_exclusive_access();
    current_task_inner.prio = prio;
    prio
}
```

为 TCB 实现比较，用于小根堆。

```rust
// task/task.rs
impl PartialOrd for TaskControlBlock {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        let self_inner = self.inner_exclusive_access();
        let other_inner = other.inner_exclusive_access();
        if self_inner.stride > other_inner.stride {
            Some(Ordering::Less)
        }
        else if self_inner.stride == other_inner.stride {
            Some(Ordering::Equal)
        }
        else if self_inner.stride < other_inner.stride {
            Some(Ordering::Greater)
        }
        else {
            None
        }
    }
}

impl PartialEq for TaskControlBlock {
    fn eq(&self, other: &Self) -> bool {
        let self_inner = self.inner_exclusive_access();
        let other_inner = other.inner_exclusive_access();
        self_inner.stride == other_inner.stride
    }
}

impl Eq for TaskControlBlock {}

impl Ord for TaskControlBlock {
    fn cmp(&self, other: &Self) -> core::cmp::Ordering {
        self.partial_cmp(other).unwrap()
    }
}
```

Manager 换用小根堆。

```rust
// task/manager.rs
use alloc::collections::binary_heap::BinaryHeap;
// ...
pub struct TaskManager {
    ready_queue: BinaryHeap<Arc<TaskControlBlock>>,
}
```

修改一下 `fetch`，搞定。剩下的问题让编译器弄。

```rust
// task/manager.rs
// impl TaskManager
pub fn fetch(&mut self) -> Option<Arc<TaskControlBlock>> {
    if let Some(tcb) = self.ready_queue.pop() {
        let mut inner = tcb.inner_exclusive_access();
        inner.stride += BIG_STRIDE / (inner.prio as usize);
        drop(inner);
        Some(tcb)
    }
    else {
        None
    }
}
```

由于这个 lab 的测试用例还没有弄好，只能自己简单测测了。对于 stride 算法深入部分的内容，我没有实现，但是可以想想：由于每次操作都是给最小的 stride 值加上不大于 `BigStride / 2` 的值，假设队列内任务数大于二，由数学归纳法（$\text{SM}$ 即 `STRIDE_MAX`，$\text{SN}$ 即 `STRIDE_MIN`，$\text{B}$ 即 `BigStride`，$\text{SSM}$ 为第二小值，有 $\text{SSM} > \text{SM}$）：

1. 假设第 $k$ 次调度时，$\text{SM}_k – \text{SN}_k \le \text{B} / 2$；
2. 那么在 $k+1$ 次调度时，假设增加步长为 $b$，
    - 若 $b < \text{SM}_k – \text{SN}_k$， $\text{SM}_{k+1} – \text{SN}_{k+1} \le \text{SM}_k – \text{SN}_k \le B/2$
    - 若 $\text{SM}_k – \text{SN}_k \le b \le B/2$，$\text{SM}_{k+1} – \text{SN}_{k+1} \le \text{SM}_k + B/2 – \text{SSM}_k \le B/2$。

有第零次调度，所有 stride 相等，满足条件， 证毕。

如果这样实现的话，新加入的 stride 必须等于 `STRIDE_MIN`。`PartialOrd` 的也实现需要 `STRIDE_MIN`。

## 第六章

这个教程的 easyfs 设计挺怪的，vfs 和磁盘块管理层没有很好分离，inode，efs 和 BlockDevice 的归属关系也挺乱的；代码设计也有些不符合常理的地方，比如该 static 的地方没办法 static，有点混乱。但是还是能改。

### 实践作业

依赖中的 k210-soc 又挂掉了，我只能按自己的理解试着实现了。

```rust
// easyfs/src/vfs.rs
// impl Inode
fn get_inodes_by_name(&self, name: &str) -> Option<(Arc<Inode>, DiskInode, u32)> {
    let Some(inode) = self.find(name) else { return None };
    let disk_inode = inode.read_disk_inode(|i| { i.clone() });
    let Some(disk_inode_id) = inode.find_inode_id(name, &disk_inode) else { return None; };
    Some((inode, disk_inode, disk_inode_id))
}

pub fn create_link_dirent(&self, name: &str, targ_name: &str) -> i32 {
    if name == targ_name { return -1 };
    let Some((targ_inode, mut targ_disk_inode, targ_disk_inode_id))
    = self.get_inodes_by_name(targ_name) else { return -1; };
    // append file in the root inode dirent
    let mut fs = self.fs.lock();
    self.modify_disk_inode(|root_inode| {
        let file_count = (root_inode.size as usize) / DIRENT_SZ;
        let new_size = (file_count + 1) * DIRENT_SZ;
        // increase size
        self.increase_size(new_size as u32, root_inode, &mut fs);
        // write dirent
        let dirent = DirEntry::new(name, targ_disk_inode_id.into());
        root_inode.write_at(
            file_count * DIRENT_SZ,
            dirent.as_bytes(),
            &self.block_device,
        );
    });
    // update nlink
    targ_disk_inode.nlink += 1;
    targ_inode.modify_disk_inode(|inode| { *inode = targ_disk_inode; });
    0
}

pub fn remove_link_dirent(&self, name: &str) -> i32 {
    let Some((inode, mut disk_inode, _disk_inode_id))
    = self.get_inodes_by_name(name) else { return -1; };
    // delete the dirent
    // let mut fs = self.fs.lock();
    self.modify_disk_inode(|root_inode| {
        let file_count = (disk_inode.size as usize) / DIRENT_SZ;
        let mut dirent = DirEntry::empty();
        for i in 0..file_count {
            assert_eq!(
                disk_inode.read_at(
                    DIRENT_SZ * i,
                    dirent.as_bytes_mut(),
                    &self.block_device,
                ),
                DIRENT_SZ,
            );
            if dirent.name() == name {
                // write a empty dirent
                let dirent = DirEntry::new("", 0);
                root_inode.write_at(
                    i * DIRENT_SZ,
                    dirent.as_bytes(),
                    &self.block_device,
                );
            }
        }
    });
    // update nlink
    disk_inode.nlink += 1;
    inode.modify_disk_inode(|inode| { *inode = disk_inode; });
    0
}

pub fn stat(&self, name: &str) -> Option<Stat> {
    let Some((_inode, disk_inode, disk_inode_id))
    = self.get_inodes_by_name(name) else { return None; };
    Some(Stat {
        dev: 0,
        ino: disk_inode_id.into(),
        mode: if disk_inode.is_file() { StatMode::FILE } else { StatMode::FILE },
        nlink: disk_inode.nlink,
        pad: [0; 7],
    })
}
```

由于擦除文件没实现，擦除一个 `DirEnt` 也很复杂，所以索性留白了，至少下次访问是不合法的。

## 第七章

本章是 IPC 和 Signal。Lab 是邮箱，懒得写了。

## 第八章

Lab 是 ELO 和 实现 eventfd，挖个坑，做完项目设计回来写。

## 第九章

Lab 是加入 virtio-gpu 驱动，挖个坑，做完项目设计回来写。

