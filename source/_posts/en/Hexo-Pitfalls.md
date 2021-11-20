---
title: Hexo Pitfalls
date: 2021-10-13 10:19:30
updated: 2021-11-20 22:54:10
tags: Tech
---

Here are the useful blogs, packages and resources that I learned from to build this site.

And following the list of changes, I can reproduce this site quickly. This is why the blog is also helpful for me.

## Theme of Hexo-Next

It's an elegant theme with a lot of effortless customizations.


## Internationalization:

The i18n package, which can generate directories for languages, but still not perfect.

[hexo-generator-i18n](https://github.com/Jamling/hexo-generator-i18n)

Other solutions like moving the whole site to a sub-folder.

[Hexo站点建设之——国际化(i18n)](https://blog.csdn.net/calvin_zhou/article/details/110957632)


## Problems of nunjucks collision:

In short: do not type `{{` or `}}` in equations, use `{ {` or `} }` instead.

[Hexo 特殊符号的转义问题](http://wxnacy.com/2018/01/12/hexo-specific-symbol/)

[Hexo博客系统报错解决方案](https://blog.csdn.net/violetjack0808/article/details/79472256)


## $\LaTeX$ Support:

[Math Equations](https://github.com/theme-next/hexo-theme-next/blob/master/docs/MATH.md)

[Hexo渲染LaTeX公式](https://www.jianshu.com/p/9b9c241146bc)

For $\LaTeX$, I prefer to use Ktex for faster experience. However it doesn't break lines. Thus I am compelled to use mathjax based solutions, which are slow for voluminous equations.

## Excerpt settings:

[hexo-excerpt](https://github.com/chekun/hexo-excerpt)

## Images loading:

[资源文件夹](https://hexo.io/zh-cn/docs/asset-folders)

## Viewer statistics:

[busuanzi](https://github.com/JoeyBling/busuanzi.pure.js)

[https://inspiring26.github.io/2019/10/10/hexo%E5%BC%80%E5%90%AFbusuanzi%E9%98%85%E8%AF%BB%E9%87%8F%E7%BB%9F%E8%AE%A1/](https://inspiring26.github.io/2019/10/10/hexo%E5%BC%80%E5%90%AFbusuanzi%E9%98%85%E8%AF%BB%E9%87%8F%E7%BB%9F%E8%AE%A1/)

## Comment functionality:

[Valine - 一款快速、简洁且高效的无后端评论系统](https://valine.js.org/)

[为你的Hexo加上评论系统-Valine](https://blog.csdn.net/blue_zy/article/details/79071414)

## Update time:

The functionality seems to be added into some versions of Hexo-Next. Just keep updated!

[hexo添加文章更新时间](https://www.jianshu.com/p/ae3a0666e998)