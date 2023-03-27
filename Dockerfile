FROM node:latest
MAINTAINER junyangzhang, user@junyang.me

# install hexo
RUN npm install hexo-cli -g

# build the site
COPY . /root
WORKDIR /root
RUN hexo generate

# configure nginx
ADD https://nginx.org/download/nginx-1.20.1.tar.gz .
RUN tar -xvf nginx-1.20.1.tar.gz && cd nginx-1.20.1 && ./configure && make && make install
RUN rm -f /usr/local/nginx/conf/nginx.conf
COPY nginx.conf /usr/local/nginx/conf/nginx.conf
RUN mkdir -p /var/logs/ && touch /var/logs/error.log && touch /var/logs/nginx.pid
RUN mkdir -p /usr/share/nginx/html/ && cp -r public /usr/share/nginx/html/

# finishing
RUN rm -rf /root/*

# hexo default port
EXPOSE 4000

# run hexo server
ENTRYPOINT ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]