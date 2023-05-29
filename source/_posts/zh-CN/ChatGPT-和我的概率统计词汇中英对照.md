---
title: ChatGPT 和我的概率统计词汇中英对照
date: 2023-05-29 13:13:09
tags:
 - Tech
 - 随想
 - 资源分享
---



我需要一个概率论词汇中英对照表。事情的起因，是为了帮助我一位需要参加北大光华夏令营笔试的好朋友。因为笔试只考概率论，但是题目很有可能是英文的。夏令营通知给的参考文献是 DeGroot, M. H. & Schervish, M. J. (2012). Probability and statistics (fourth edition)，这本书只有第三版有中文版。书后面有个 Index，给出了这本书里比较重要的名词、概念和人名，以及其对应的参考页码。这个 Index 有一千多词，我第一个想法是使用 ChatGPT 的 API 把它们翻译一遍。

我找到了 pdf 电子版并复制了 Index，然后用正则表达式修复了一下格式和复制错误等问题，把它弄成了纯文本形式。给点例子：

```plain
Allison, D. B., 400
Alternative hypothesis, 531
Anagnostopoulos, P., xii
Analysis of variance, 754
    one-way layout, 755
    residuals, 760
    two-way layout, 763
        with replications, 773
...
Bergin, P., xii
Bernoulli distribution, 97, 276
    conjugate prior for, 394-395
    m.g.f., 276
...
```

接下来就是按行处理。Index 给出的一些概念是有层级关系的，用缩进表示。那么按行处理文本的时候弄一个栈存一下当前词的上下文即可。所有的概念全名就是把它和先前层次的名词都连起来，虽然会有点语序问题。处理完了可以得到结构化的数据 `data`，是一个全名为 key 的字典。

```python
import re

data = {}

term_stack = []
for line in lines:
    depth = 0
    while (line.startswith("    ")):
        depth += 1
        line = line[4:]

    simp_name = re.sub(r",\s*([-\d]+|[-ivx]+)", "", line).strip()
    page_matches = re.findall(r"\b([-\d]+|[-ivx]+)\b", line)
    page_refs = [page for page in page_matches] if page_matches else []

    full_name = " ".join(term_stack[:depth] + [simp_name])
    del term_stack[depth:]
    term_stack.append(simp_name)

    entry = {
        "suffix name": simp_name,
        "pages": page_refs,
    }

    data[full_name] = entry
```

这里拿 `\b([-\d]+|[-ivx]+)\b` 来匹配页码和页码范围，但是有可能匹配到正文中的连字符 `-` 可以寻思着改进一下。

结构化的数据有了接下来是重头戏，拿 ChatGPT 翻译这些概念。

```python
import openai

openai.api_key = "YOUR KEY HERE"

def translate_term(term):
    global usage
    prompt = "Give the corresponding Simplified Chinese term given by the user. The term must be in the area of Probability and Statistics. You should only give one word or phrase without any other supplementary text or Pinyin."
    
    for _ in range(10):
        try:
            completion = openai.ChatCompletion.create(
                model = "gpt-3.5-turbo", 
                messages = [{"role": "system", "content": prompt},
                            {"role": "user", "content" : term}]
            )
        except Exception:
            print("Completion failed, retrying...")
            continue
        break

    usage += completion.usage.total_tokens
    return completion.choices[0].message.content.strip()
```

直接使用 OpenAI 的 Python 库。我本来是问了一下 ChatGPT 怎么用 API，但是 ChatGPT 只会用 `text-davinci` completion 模型，并不知晓 `gpt-3.5-turbo` 模型的存在。所以还是看了一眼官方文档。这个 `openai.ChatCompletion.create` API 是会抛异常的，包括网络不通、API 额度超限、服务器过载等等问题，所以需要简单实现个重试机制。

这个脚本花了快一个小时才跑完 1000 余个概念，基本是在等 API response，而且十几个 request 就得有一次超负荷或者断连得重试。跑出来的结果也一般。我都明确告诉它了不要附汉语拼音它有时候还是要加上。也有不少人名它不认识并告诉我这不是概率统计的内容所以拒不翻译，这个倒不怪它。下面是一些奇葩回应大赏。

| 词汇或概念                                                   | ChatGPT 的翻译                                               | 参考页码 |
| ------------------------------------------------------------ | ------------------------------------------------------------ | -------- |
| Anagnostopoulos, P.                                          | Anagnostopoulos, P. (Greek name) does not correspond to a term in the area of Probability and Statistics. Please provide a valid term. | xii      |
| Absolute error loss                                          | 绝对误差损失 (jué duì wù chā sǔn shī)                        | 411      |
| [Bayes test] relation to t test                              | 贝叶斯t检验 (Bayes t检验)                                    | 612      |
| Binomial approximation to hypergeometric distribution        | 二项式近似分布 (Er Xiang Shi Jin Fen Bu)                     | 284      |
| [Binomial distribution] relation to negative binomial distribution | 二项分布与负二项分布的关系: 负二项分布可被视为一系列相互独立的二项分布试验中，直到 r 次失败所需的试验次数的概率分布。 | 345      |
| Bush, G. W.                                                  | 布什，G.W. (Note: This is not a term in Probability and Statistics. It is the name of a person.) | 786      |
| Bootstrap confidence interval                                | 自助法置信区间                                               |          |

最后看了看这些 Index Term 和 ChatGPT 给的翻译，觉得重复率高、人名多还没用。给一个像这样的一千多个词的表并没有什么帮助，它也给不出什么信息。

几个月前，大家还觉得 ChatGPT 是什么新鲜的、能够大大提升人类生产力、提升学生的学习效率的超智能 AI。短短几周过去了，我已然觉得这个世界好像没有因为这样一个能理解并生产简单文字的 AI 而改变太多。希望以后能把这几千行直接塞给大模型，让他帮我总结经验。

于是乎，玩了几个小时后，还是回到了手工总结单词的重复劳作上。我想把我自己总结的结果贴在这里。

```plain
Part 1. Abbreviations						
Abbr.	Full Term			Zh-CN Term		
m.g.f.	Moment-generating function			矩母函数		
p.f.	Probability function			概率分布函数		
p.d.f.	Probability density function			概率密度函数		
c.d.f.	Cumulative distribution function			累计概率密度函数		
M.L.R.	Multivariate Linear Regression 			多元线性回归		
M.L.E.	Maximum likelihood estimation			极大似然估计		
i.e.	id est			即（又称为）		
e.g.	exempli gratia			举例子		
s.t.	Subject to			使得		
iff	if and only if			当且仅当		
inf/glb	infimum/greatest lower bound			极小值/最大下界		
sup/lub	supremum/least upper bound			极大值/最小上界		
min	minimum			最小值		
max	maximum			最大值		
M.A.E.	Mean absolute error			平均绝对误差		
M.S.E.	Mean squared error			均方误差		
int	interior			内部		
lcm	least common multiple			最小公倍数		
gcd	greatest common divisor			最大公约数		
mod	modulo			取模运算		
QED	Quod erat demonstrandum			证毕		
LHS/RHS	Left/Right hand side			（公式的）左/右侧部分		
tr	trace			（矩阵的）迹		
UMP test	Uniformly most powerful test			一致最强检验		
						
Part 2. Probability and Statistics Terms						
En-US Term				Zh-CN Term		
Set				集合		
Countable				可数		
Absolute				绝对的		
Error				误差		
Efficient estimation				有效估计		
Unbiased estimation				无偏估计		
Inadmissible estimation				（国内课本似乎没有这个概念）		
Consistent estimation				一致估计		
Robust estimation				稳健估计		
Least-squares estimation				最小二乘估计		
Estimator				估计量		
Predictor				预测量		
Aggregated				汇总		
Alias				别名		
Genotype				基因型		
Allele				等位基因		
Assumptions				假设（模型假设）		
Hypothesis				假设（假设检验）		
Null Hypothesis				零假设		
One-sided Hypothesis				单侧假设		
Reject Hypothesis				拒绝假设		
Interquartile range				四分位距		
Lower/Upper quartile				上/下四分位点		
Percentile				百分位点		
Quantile				分位数		
Median				中位数		
Expectation				期望		
Mode				众数		
Mean				均值		
Conditional mean				条件均值		
Grand mean				总均值		
Trimmed mean				修剪平均数		
Harmonic mean				调和平均数		
Variance				方差		
Residual				残差		
Central Moment				中心矩		
One-way layout ANOVA				单因素方差分析		
Antithetic variates				对偶变量		
Multiplication rule				乘法原理		
Additivity				可加性		
Asymptotic				渐进的		
Distribution				分布		
Augmented				增强的、增广		
Auxiliary				辅助的		
Benoulli				伯努利		
Poisson				泊松		
Cauchy				柯西		
Bayes				贝叶斯		
Liapounov				李雅普诺夫		
Lindeberg and Le ́vy				林德伯格和莱维		
Chebyshev				切比雪夫		
Gram-Schmidt method				格拉姆-施密特正交化		
Markov chain stationary distribution				马尔可夫链稳态分布		
Pearson				皮尔逊		
Theorem				定理		
Axiom				公理		
Law of large numbers				大数定理		
Regression				回归		
Bivariate				双变量		
Multivariate				多变量		
Process				过程		
Inference				推理		
Event				事件		
Random variable				随机变量		
Sample				采样		
Test				检验		
Trial				试验		
Binomial				二项式的		
multinomial				多项式的		
Coefficient				系数		
Parameter				参数		
Nonparametric				非参数的		
Factor				因素		
Conjugate				共轭		
Confidence interval				置信区间		
Bootstrap methods				Bootstrap 方法		
Central limit theorem				中心极限定理		
Moment				矩		
Classical interpretation of probability				古典概型		
Combinations				组合		
Complement				互补事件		
Composite				复合的		
Independent				独立的		
Uniform				一致的、均匀的		
Family				族		
Contaminate				污染		
Contingency table				列联表		
Joint distribution				联合分布		
Discrete				离散的		
Continuous				连续的		
Converge				收敛		
Convex function				凸函数		
Correlation				相关性		
Pivotal				关键的		
Critical				临界的		
Dimension				维度		
Exponential				指数的		
Geometric				几何的		
Posterior distribution				后验分布		
Prior distribution				先验分布		
Normal				正态		
Distributive properties				分配律		
Dominate				支配		
Algorithm				算法		
Empirical c.d.f.				经验分布函数		
Equivalence				等价		
Extrapolation				外推		
Criterion				准则		
Goodness-of-fit test				拟合优度检验		
Histogram				直方图		
Hyper-				超-（词缀）		
Hypo-				次-（词缀）		
Series				级数		
Sufficient				充分		
Level of significance				显著水平		
Likelihood function				似然函数		
Marginal distribution				边缘分布		
Vector				向量		
Normalize				归一化		
Partition				划分		
Sign				符号		
Ranktest				秩和检验		
Reliability				可靠性		
Paradox				悖论		
Skewness				偏度		
Stochastic process				随机过程		
Stratified				分层的		
Trigamma function				三次对角函数		
Utility function				效用函数		
```

