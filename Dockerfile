FROM node:latest
MAINTAINER junyangzhang, user@junyang.me

# install hexo
RUN npm install hexo-cli -g
WORKDIR /root/src
COPY . /root/src
RUN npm install

# install pandoc
ADD https://github.com/jgm/pandoc/releases/download/3.1.1/pandoc-3.1.1-1-amd64.deb .
RUN dpkg -i pandoc-3.1.1-1-amd64.deb

# build the site
RUN hexo generate

# configure nginx
ADD https://nginx.org/download/nginx-1.20.1.tar.gz .
RUN tar -xvf nginx-1.20.1.tar.gz && cd nginx-1.20.1 && ./configure && make && make install
RUN rm -f /usr/local/nginx/conf/nginx.conf
COPY nginx.conf /usr/local/nginx/conf/nginx.conf
RUN mkdir -p /var/logs/ && touch /var/logs/error.log && touch /var/logs/nginx.pid
RUN mkdir -p /usr/share/nginx/html/ && cp -r public /usr/share/nginx/html/

# finishing
RUN rm -rf /root/src

# hexo default port
EXPOSE 4000

# run hexo server
ENTRYPOINT ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]