---
title: 利用 eBPF XDP 编写一个实验用防火墙
date: 2022-03-09 14:56:10
tags: CS
---

不明所以的 SDN 老师出了一道实机实验题，要求模拟下面的过程，中途丢掉某个特定的包。

![procedure.jpg](/images/ePBFFirewall/procedure.jpg)

拔网线大概会直接丢所有的包，后来要求收到的包就模拟不出来了，而且十分考验手速。或者使用现有的防火墙程序，但按内容匹配也不容易。另一种方式是使用 mininet，笔者不太会 mininet。不过正好笔者了解过 eBPF，也正要学习，于是用 eBPF 写一个 XDP 防火墙，支持内容匹配。

我们的目的是用 BPF 实现一个 XDP（eXpress Data Path）程序，绑定在本机 loopback 接口上，匹配到 A 到 B 内容为 `Are you OK?` 的包，然后把它过滤掉。

不了解 eBPF 的话可以先看一下这篇博客 [eBPF 技术介绍-刘达的博客](https://imliuda.com/post/1047)

本文的 repo：[eBPF-PayloadFilter](https://github.com/James-Hen/eBPF-PayloadFilter)

## 实现主机 A 和 B

使用 Socket 实现 TCP 连接已经老生常谈了，这次我们把它们绑定到 Loopback 接口；A 的端口 `1145`，B 的端口 `5141`，A 作为服务器。 `experiment.c` 的简化代码是这样的，错误处理省略掉了：

```c
// experiment.c
#define A_PORT 1145
#define B_PORT 5141

void host_A() {
    // SOCKET
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT,
                                                &opt, sizeof(opt));
    // BIND to 1145
    struct sockaddr_in address;
    int addrlen = sizeof(address);
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(A_PORT);
    bind(server_fd, (struct sockaddr *)&address,
                                sizeof(address));
    // LISTEN
    listen(server_fd, 3);
    // ACCEPT
    int new_socket = accept(server_fd, (struct sockaddr *)&address,
                    (socklen_t*)&addrlen))；

    char buffer[1024] = {0};
    char *hello = "Hello!", *areuok = "Are you OK?";
    // A sends "Hello!"
    send(new_socket, hello, strlen(hello), 0);
    // After ACK, A sends "Are you OK?"
    send(new_socket, areuok, strlen(areuok), 0);
    // B sends "Hello!"
    int valread = read(new_socket, buffer, 1024);
}

void host_B() {
    // SOCKET
    int client_fd = socket(AF_INET, SOCK_STREAM, 0);
    // BIND to 5141
    struct sockaddr_in cli_addr;
    cli_addr.sin_family = AF_INET;
    cli_addr.sin_port = htons(B_PORT);
    bind(client_fd, (struct sockaddr *)&cli_addr, sizeof(cli_addr));
    // CONNECT to localhost:1145
    struct sockaddr_in serv_addr;
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(A_PORT);
    inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr);
    connect(client_fd, (struct sockaddr *)&serv_addr, sizeof(serv_addr));

    char buffer[1024] = {0};
    // B reads "Hello!" and ACK
    int valread = read(client_fd, buffer, 1024);
    // B sends "Hello!"
    char *hello = "Hello!";
    send(client_fd, hello ,strlen(hello) ,0);
    // B reads "Are you OK?" and ACK
    valread = read(client_fd, buffer, 1024);
}

int main(int argc, char const *argv[]) {
    int B_pid = fork();
    if (B_pid == 0) { // B
        sleep(1); // Let A start first
        host_B();
    }
    else { // A
        host_A();
    }
    return 0;
}
```

## eBPF 工具链准备

既然是 eBPF，必须是 Linux 了，Win 和 MacOS 不好使。

虽然可以使用 `libbpfcc` 和 Python 实现简单的编译和启用，但无奈在我们的服务器上存在权限问题，所以转战 `libbpf`。但是 `libbpf` 在新的 Ubuntu 20.04 LTS 上不存在了（会有 `E: Unable to locate package libbpf` 错误），需要从源码编译，我在 repo 里已经把它作为 submodule，使用 Makefile 自动编译了。

再者就是需要 LLVM 和 Clang 作为编译器来生成 eBPF 字节码。

实验抓包可以使用命令行版本的 WireShark——TShark，使用 TShark 抓包可以生成 `.pcapng` 文件，可以利用图形界面的 WireShark 分析。

可以这样使用 TShark 抓取 1145 端口的 TCP 包：

```bash
sudo tshark -i lo -f "tcp port 1145" -w "./result.pcapng" -P -a duration:5
```

其中 `-i` 选取设备（`lo` 是本地环回接口）；`-f` 设置一个过滤条件（和 WireShark 的显示条件语法不一样）；`-w` 写入一个文件；`-P` 在写入文件的同时把格式化的输出放到 stdout；`-a duration:5` 设置抓包五秒

## 编译并加载 eBPF 程序

上代码之前先看看怎么编译：

```bash
clang -I/usr/include/x86_64-linux-gnu -Ibuild/usr/include -O3 -target bpf -c filter.c -o filter.o
```

指定的 include 目录包括了系统的目录和 libbpf 的安装目录。必须使用 Clang 才能使用 LLVM 提供的 BPF 字节码后端。可以试试查看 BPF 字节码长什么样：

```
$ llvm-objdump -D filter.o
[...]
Disassembly of section prog:

0000000000000000 xdp_func:
       0:       b7 00 00 00 02 00 00 00 r0 = 2
       1:       61 12 04 00 00 00 00 00 r2 = *(u32 *)(r1 + 4)
       2:       61 13 00 00 00 00 00 00 r3 = *(u32 *)(r1 + 0)
       3:       bf 31 00 00 00 00 00 00 r1 = r3
       4:       07 01 00 00 0e 00 00 00 r1 += 14
       5:       2d 21 53 00 00 00 00 00 if r1 > r2 goto +83 <LBB0_12>
       6:       bf 31 00 00 00 00 00 00 r1 = r3
       7:       07 01 00 00 22 00 00 00 r1 += 34
       8:       2d 21 50 00 00 00 00 00 if r1 > r2 goto +80 <LBB0_12>
       9:       bf 34 00 00 00 00 00 00 r4 = r3
      10:       07 04 00 00 36 00 00 00 r4 += 54
      11:       2d 24 4d 00 00 00 00 00 if r4 > r2 goto +77 <LBB0_12>
[...]
```

可以看出它是“64 位指令字长的 RISC 架构”，BPF 的内核态 JIT 引擎会在 Verifier 验证后（这个验证非常严格），把这些字节码翻译成宿主机的指令集机器码来执行。

通过下面的命令把编译出来的字节码丢给 Kernel，其中 `lo` 是环回接口，`xdp` 是程序类型：

```bash
ip link set dev lo xdp obj filter.o
```

可以这样关闭它：

```bash
ip link set dev lo xdp off
```

如果担心是不是没关掉或者误加载了，可以使用 `ip link list` 查看一下。

## 先实现一个能编译的板子

（用 BPF 实现的）XDP 程序的结构是这样的，前面加了一些问题描述中用到的定义：

```c
// filter.c: drop all A->B TCP packets
#include <arpa/inet.h>
#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/tcp.h>

// The pattern that will be matched
const char match_pattern[] = "Are you OK?";
// The ports of src and dst
#define A_PORT 1145
#define B_PORT 5141

// Tell clang that the section name of the function is prog
SEC("prog")
int xdp_func(struct xdp_md *ctx) {
    // ctx: the pointer to the frame and relevant fields
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;
    // Ethernet header is the first one
    struct ethhdr *eth = data;
    if ((void *)eth + sizeof(*eth) > data_end)  // Overflow detection
        return XDP_PASS; // PASS
    // Calculate the IP header address, must't overflow because tested
    struct iphdr *ip = data + sizeof(*eth);
    if ((void *)ip + sizeof(*ip) > data_end)    // Overflow detection
        return XDP_PASS;
    // If not IP protocol
    if (ip->protocol != IPPROTO_TCP)
        return XDP_PASS;
    // Calculatethe TCP header address
    struct tcphdr *tcp = (void *)ip + sizeof(*ip);
    if ((void *)tcp + sizeof(*tcp) > data_end)  // Overflow detection
        return XDP_PASS;
    // Match the source and target port
    // htons: host to network (byte order) short
    if (tcp->source != htons(A_PORT) || tcp->dest != htons(B_PORT))
        return XDP_PASS;
    return XDP_DROP; // Drop it!
}
```

看得出来，他会把所有的 A 到 B 的 TCP 包通过端口匹配丢掉，可以试试跑 `experiment` 来看看能不能过滤。

XDP 程序中写了很多溢出的判断，这里的判断都保证了计算下一个包头位置不会达到无效内存。虽然对于正常的帧看起来显然不会溢出，但是 BPF 的 Verifier 会检查你有没有检查，否则是不愿意把你 JIT 进内核的。

## 字符串匹配

XDP 有严格的函数调用限制，`strcmp` 是完全不能用的。有些情况下 `__builtin_memcmp` 可以用，但是我没用成功。BPF 程序基本不支持循环，但是可以使用 `#pragma unroll` 预处理指令让编译器把常数上下限的循环给完全展开：

```c
// filter.c (part)
// include and some global variables ignored

// The pattern that will be matched
const char match_pattern[] = "Are you OK?";

SEC("prog")
int xdp_func(struct xdp_md *ctx) {
    // ignored Ethernet, TCP, IP header tests
    
    // Here we begin to check payloads
    uint32_t payload_size = // ip total length - ip header length - tcp data offset
        ntohs(ip->tot_len) - ((uint32_t)(ip->ihl) << 2) - tcp_hdrl(tcp);
    uint32_t pattern_size = sizeof(match_pattern) - 1;
    if (payload_size != pattern_size) 
        return XDP_PASS;
    // Point to start of payload.
    payload = (const char *)tcp + tcp_hdrl(tcp);
    if ((void *)payload + payload_size > data_end)
        return XDP_PASS;
    // Compare first bytes, exit if a difference is found.
#pragma unroll
    for (int i = 0; i < payload_size; i++)
        if (match_pattern[i] != payload[i])
            return XDP_PASS;
    // matched, Drop it
    return XDP_DROP;
}
```

哦对了，出现了一个 `tcp_hdrl(tcp)`。它其实是我自己写的宏，来取得 TCP 的头长度（也是数据的 Offset）。为啥不是个简单的字段呢？因为有些实现是 BSD 标准，可以参照 [tcp.h](https://sites.uclouvain.be/SystInfo/usr/include/netinet/tcp.h.html)。另外，这个偏移量是以 4 字节（32 位）为单位的。

```c
#ifdef __FAVOR_BSD
    #define tcp_hdrl(hdr) ((uint32_t)(hdr->th_off) << 2)
#else
    #define tcp_hdrl(hdr) ((uint32_t)(hdr->doff) << 2)
#endif
```

## 需要 Debug！

万一写挂了，这东西完全没有调试器，没有断点可以打。只能 print 些什么，但是连 `printf` 也不能用！所幸 `libbpf` 提供了 `bpf_trace_printk()`，提供类似 `printf` 的功能，但是：

 - 它最多只可以格式化输出三个变量的值
 - 必须传格式字符串的长度
 - 在程序中必须声明使用 [GPL-compatible](https://github.com/torvalds/linux/blob/master/include/linux/license.h) 许可证开源

唉，虽然不喜欢 GPL，但是至少 MIT 和 BSD 是能 GPL-compatible 的。至于前两个限制，可以写一个宏解决（来自 [BPF Reference Guide](https://www.gigamon.com/content/dam/resource-library/english/guide---cookbook/gu-bpf-reference-guide-gigamon-insight.pdf)）。

```c
#include <bpf/bpf_helpers.h>
#define DEBUG
char LICENSE[] SEC("license") = "Dual MIT/GPL";
#define printk(fmt, ...)                            \
({                                                  \
        char ____fmt[] = fmt;                       \
        bpf_trace_printk(____fmt, sizeof(____fmt),  \
                         ##__VA_ARGS__);            \
})
SEC("prog")
int xdp_func(struct xdp_md *ctx) {
#ifdef DEBUG
    printk("Payload filter debugging enabled!\n");
#endif
    return XDP_PASS;
}
```

## 我只想丢一次怎么办

如果我按照上面的说法写防火墙，那么我内容是 `Are you OK?` 的包就再也传不到了，程序只有在超时重传开始摆烂才能真正退出来，很难受，也没法好好做实验。怎么办呢，我搞个全局变量记一下丢了几个包？

很可惜没有这么简单，XDP 不允许全局的可变量~~，淦~~。但是内核为了实现 Stateful 的网络设计（比如 NAT 和虚连接），给你提供了它的一些数据结构的接口。那么我们就用它的 `BPF_MAP_TYPE_HASH` 来实现一下记住我丢了几次吧（虽然我只用一个值就行）。

```c
// Packet drop counts, implement as eBPF map, just using map[0] as counter
#define DROP_COUNT 1
#define MAX_ENTRIES	16
struct bpf_map_def SEC("maps") drop_map = {
	.type = BPF_MAP_TYPE_HASH,
	.key_size = sizeof(uint32_t),
	.value_size = sizeof(uint32_t),
	.max_entries = MAX_ENTRIES,
};

SEC("prog")
int xdp_func(struct xdp_md *ctx) {
    // a lot omitted here...
    // will reach here only if matched the pattern "Are you OK?"

    // Stateful: only drop DROP_COUNT times
    uint32_t key = 0, init_val = DROP_COUNT;
    // Update only if it doesn't exist
	bpf_map_update_elem(&drop_map, &key, &init_val, BPF_NOEXIST);
    uint32_t *val = bpf_map_lookup_elem(&drop_map, &key);
	if (val && *val) {
        int new_val = *val - 1;
        bpf_map_update_elem(&drop_map, &key, &new_val, BPF_ANY);
        return XDP_DROP;
    }
    
    // Match but had dropped, pass
    return XDP_PASS;
}
```

这样就把这个实验做好了，搞了一天半属实有点大动干戈，但是学了不少好东西呢！

## References

 - [BPF Reference Guide](https://www.gigamon.com/content/dam/resource-library/english/guide---cookbook/gu-bpf-reference-guide-gigamon-insight.pdf)
 - [BPF tips & tricks: the guide to bpf_trace_printk() and bpf_printk()](https://nakryiko.com/posts/bpf-tips-printk/)
 - [Tutorial: Tracing03 - debug print](https://github.com/xdp-project/xdp-tutorial/tree/master/tracing03-xdp-debug-print)
 - [eBPF 系列三：eBPF map ](https://vvl.me/2021/02/eBPF-3-eBPF-map/)