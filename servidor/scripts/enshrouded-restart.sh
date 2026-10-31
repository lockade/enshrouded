#!/bin/bash
# Uso: enshrouded-restart.sh            -> reinicia só se ninguém estiver online
#      enshrouded-restart.sh --forcar   -> reinicia sempre
#      enshrouded-restart.sh --teste    -> só mostra quantos jogadores estão online
cd /opt/enshrouded-server || exit 1
LOG=/var/log/enshrouded-restart.log
agora() { date '+%F %T'; }

jogadores=$(/usr/bin/docker compose logs --since 2m 2>/dev/null \
  | grep -E "Machines:|m#[0-9]+\(" | tac \
  | awk '/Machines:/{exit} {print}' \
  | grep -c "m#[1-9]")

if [ "$1" = "--teste" ]; then
  echo "Jogadores online: $jogadores"
  exit 0
fi

if [ "$jogadores" -gt 0 ] && [ "$1" != "--forcar" ]; then
  echo "$(agora) $jogadores jogador(es) online - restart adiado" >> "$LOG"
  exit 0
fi

echo "$(agora) reiniciando servidor (jogadores online: $jogadores)" >> "$LOG"
/usr/bin/docker compose exec -T enshrouded supervisorctl restart enshrouded-server >> "$LOG" 2>&1
