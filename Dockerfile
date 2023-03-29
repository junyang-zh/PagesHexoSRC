# first stage: build the site using node
FROM node:latest

MAINTAINER junyangzhang, user@junyang.me

# install hexo and others in package.json
WORKDIR /root/src
COPY . /root/src
RUN npm install hexo-cli -g && npm install

# install pandoc
ADD https://github.com/jgm/pandoc/releases/download/3.1.1/pandoc-3.1.1-1-amd64.deb .
RUN dpkg -i pandoc-3.1.1-1-amd64.deb

# make inplace style changes
RUN chmod +x customization/alter_styles.sh && ./customization/alter_styles.sh

# build the site
RUN hexo generate

# second stage: configure nginx
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/hexosite.conf
RUN mkdir -p /var/logs/ && touch /var/logs/error.log && touch /var/logs/nginx.pid

# get the built site from the node stage
RUN mkdir -p /usr/share/nginx/html/
COPY --from=0 /root/src/public /usr/share/nginx/html/

# finishing
RUN rm -rf /root/src

# hexo default port
EXPOSE 4000

# run hexo server
ENTRYPOINT ["/usr/sbin/nginx", "-g", "daemon off;"]
