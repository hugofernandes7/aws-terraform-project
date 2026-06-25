FROM nginx:stable-alpine
ADD init.sh /init.sh
ADD GeoIP.dat /usr/share/GeoIP/GeoIP.dat
RUN apk add goaccess --no-cache --update --repository http://nl.alpinelinux.org/alpine/edge/main/ --allow-untrusted
CMD ["/init.sh","-g","daemon off;"]

