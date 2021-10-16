---
title: Solution on 2018 ICPC Asia Nanjing Regional M
lang: en
date: 2021-10-16 20:27:11
tags: Problem Solution
---

Today we virtually participated the regional of 2018 Nanjing, and I have done my first non-trivial string problem, introducing a new algorithm called Extended-KMP. Thus I bet it notable on by blog.

## Problem Statement

> Given two strings s and t, count the number of tuples $(i, j, k)$ such that
>
> 1. $1\le i\le j\le |s|$
> 2. $1\le k\le |t|$
> 3. $j − i + 1 > k$
> 4. The $i$-th character of $s$ to the $j$-th character of $s$, concatenated with the first character of $t$ to the $k$-th character of $t$, is a palindrome.
>
> $2\le |s|\le 10^6$, $1\le |t|<|s|$

## Solution

The problem is to find and count the number of cases that there is two adjacent substrings $s^{(1)}$, $s^{(2)}$ in $s$ and another $t^{(1)}$ in $t$, provided that $s^{(2)}$ is a palindrome, and $s^{(1)}$ is reversely matched with $t^{(1)}$.

So let's reverse the string $s$. Then use the famous Manacher algorithm on $s$ (when there is a longest palindrome $s_x\cdots s_y$, let $p_{x+y}=\lfloor(y-x+1)/2\rfloor$) and count every occurrence centered at $i=\lceil(x+y)/2\rceil$.

Let $s^j$ be the suffix of $s$ starting from $j$. We should firstly find the longest common prefix of suffix $s^j$ and $t$, and sum up the length of these prefixes around $i$. Precisely, all of the prefixes starting from $i+1$ to $i+p_{x+y}$ should be counted. Using prefix sum, we could get that value in $O(1)$ at every symmetrical center.

It must be noted that $j-i+1>k$, then $s_2$ must not be empty.

Dealing with bounds and indexes of strings is tricky, so be careful.

## Code

```cpp
#include <bits/stdc++.h>
using namespace std;
const int MaxN(2e6+10);
char s[MaxN], t[MaxN];
int palin[MaxN]; // the half length of palindrome centered at i/2
void manacher(char str[], int len[], int n) {
    len[0] = 1;
    for (int i(1), j(0); i < (n << 1) - 1; ++i) {
        int p(i >> 1), q(i - p), r(((j + 1) >> 1) + len[j] - 1);
        len[i] = r < q ? 0 : min(r - q + 1, len[(j << 1) - i]);
        while (p > len[i] - 1 && q + len[i] < n && str[p - len[i]] == str[q + len[i]])
            ++len[i];
        if (q + len[i] - 1 > r)
            j = i;
    }
}
// Extended KMP
void GetNext(char *T, int & m, int next[]) {
    int a = 0, p = 0;
    next[0] = m;
    for (int i = 1; i < m; i++) {
        if (i >= p || i + next[i - a] >= p) {
            if (i >= p)
                p = i;
            while (p < m && T[p] == T[p - i])
                p++;
            next[i] = p - i;
            a = i;
        }
        else
            next[i] = next[i - a];
    }
}
void GetExtend(char *S, int & n, char *T, int & m, int extend[], int next[]) {
    int a = 0, p = 0;
    GetNext(T, m, next);
    for (int i = 0; i < n; i++) {
        if (i >= p || i + next[i - a] >= p) {
            if (i >= p)
                p = i;
            while (p < n && p - i < m && S[p] == T[p - i])
                p++;
            extend[i] = p - i;
            a = i;
        }
        else
            extend[i] = next[i - a];
    }
}
int Next[MaxN], Lcsp[MaxN]; // longest common prefix of suffix s_i and t
using LL = long long;
LL SLcsp[MaxN]; // prefix sum of Lcsp
int main() {
    scanf("%s", s);
    scanf("%s", t);
    int ls(strlen(s)), lt(strlen(t));
    // reverse the string s
    for (int i(0); i < ls / 2; ++i) {
        swap(s[i], s[ls - i - 1]);
    }
    manacher(s, palin, ls);
    GetExtend(s, ls, t, lt, Lcsp, Next);
    // prefix sum
    for (int i(0); i < ls; ++i) {
        SLcsp[i + 1] = SLcsp[i] + Lcsp[i];
    }
    LL ans(0);
    for (int i(0); i < ls + ls - 1; ++i) {
        if (i & 1) { // even length palindrome
            int mid((i + 1) / 2); // to exclude empty palindrome part
            ans += SLcsp[min(mid + palin[i] + 1, ls)] - SLcsp[mid + 1];
        }
        else { // odd length palindrome
            int mid(i / 2);
            ans += SLcsp[min(mid + palin[i] + 1, ls)] - SLcsp[mid + 1];
        }
    }
    printf("%lld\n", ans);
    return 0;
}
```

