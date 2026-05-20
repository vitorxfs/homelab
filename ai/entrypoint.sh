#!/bin/sh
set -e

# Define a senha do usuário claude a partir da env var
if [ -n "$SSH_PASSWORD" ]; then
  echo "claude:$SSH_PASSWORD" | chpasswd
else
  echo "ERRO: SSH_PASSWORD não definida — configure no .env"
  exit 1
fi

# Instala authorized_keys vindo do volume com as permissões corretas (opcional)
if [ -f /tmp/authorized_keys ]; then
  mkdir -p /home/claude/.ssh
  cp /tmp/authorized_keys /home/claude/.ssh/authorized_keys
  chown -R claude:claude /home/claude/.ssh
  chmod 700 /home/claude/.ssh
  chmod 600 /home/claude/.ssh/authorized_keys
fi

# Repassa ANTHROPIC_API_KEY para sessões SSH (env do docker não chega lá por padrão)
if [ -n "$ANTHROPIC_API_KEY" ]; then
  echo "export ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY'" > /home/claude/.profile
  chown claude:claude /home/claude/.profile
fi

exec /usr/sbin/sshd -D -e
