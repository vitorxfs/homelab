FROM alpine:3.21

RUN apk add --no-cache nodejs npm git bash openssh

RUN npm install -g @anthropic-ai/claude-code

# Usuário não-root para sessões SSH
RUN adduser -D -s /bin/bash claude

# Host keys do sshd
RUN ssh-keygen -A

# Hardening: aceita chave e password, sem root
RUN sed -i \
    -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' \
    -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
    -e 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' \
    /etc/ssh/sshd_config

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
