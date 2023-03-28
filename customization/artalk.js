/* global hexo */

'use strict';

const path = require('path');
//const { iconText } = require('./common');

// Add comment
hexo.extend.filter.register('theme_inject', injects => {
  const config = hexo.theme.config.artalk;
  if (!config.enable) return;

  injects.comment.raw('artalk', `
  <!-- CSS -->
  <link href="https://cdnjs.cloudflare.com/ajax/libs/artalk/2.5.2/Artalk.css" rel="stylesheet">
  <!-- JS -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/artalk/2.5.2/Artalk.js"></script>
  <!-- Artalk -->
  <div id="Comments" style="padding-top: 20px;"></div>
  <script>
  Artalk.init({ el: '#Comments', server: 'https://blogbackend.junyang.me:23366', })
  </script>
  `, {}, { cache: true });

  injects.bodyEnd.file('artalk', path.join(hexo.theme_dir, 'layout/_third-party/comments/artalk.njk'));

});

// Add post_meta
/*
hexo.extend.filter.register('theme_inject', injects => {
  const config = hexo.theme.config.artalk;
  if (!config.enable || !config.shortname || !config.count) return;

  injects.postMeta.raw('artalk', `
  {% if post.comments %}
  <span class="post-meta-item">
    ${iconText('far fa-comment', 'artalk')}
    <a title="artalk" href="{{ url_for(post.path) }}#artalk_thread" itemprop="discussionUrl">
      <span class="post-comments-count artalk-comment-count" data-artalk-identifier="{{ post.path }}" itemprop="commentCount"></span>
    </a>
  </span>
  {% endif %}
  `, {}, {});

});
*/
