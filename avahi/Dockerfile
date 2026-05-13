FROM alpine:latest

RUN apk add --no-cache avahi-tools

COPY publish.sh /publish.sh
RUN chmod +x /publish.sh

CMD ["/publish.sh"]
