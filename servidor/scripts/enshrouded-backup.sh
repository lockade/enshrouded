#!/bin/bash
# Backup do servidor de Enshrouded + envio para o GitHub
# - backup local a cada execução (guarda 7 dias)
# - último backup de cada dia em diarios/ (guarda 30 dias)
# - GitHub: 5 backups mais recentes de hoje + 1 por dia anterior
# - publica a configuração do servidor (sem senhas) em servidor/

export TZ=America/Sao_Paulo
SERVIDOR=/opt/enshrouded-server
BACKUPS=/root/enshrouded-backups
DIARIOS=$BACKUPS/diarios
REPO=/root/enshrouded-github
LOG=/var/log/enshrouded-backup.log
HOJE_MAX=5     # backups de hoje no GitHub
DIAS=30        # dias anteriores no GitHub (1 arquivo por dia)

agora() { date '+%F %T'; }
hoje=$(date +%Y%m%d)
mkdir -p "$DIARIOS"

# 1. backup local (sem as cópias internas do jogo, compressão máxima)
arquivo="$BACKUPS/world-$(date +%Y%m%d-%H%M).tar.gz"
if ! tar -I 'gzip -9' -cf "$arquivo" --exclude="savegame/backup" -C "$SERVIDOR/game/server" savegame; then
  echo "$(agora) ERRO ao criar backup local" >> "$LOG"
  exit 1
fi
find "$BACKUPS" -maxdepth 1 -name 'world-*.tar.gz' -mtime +7 -delete

# 2. backup do dia: sempre sobrescrito com o mais recente
cp "$arquivo" "$DIARIOS/dia-$hoje.tar.gz"
find "$DIARIOS" -name 'dia-*.tar.gz' -mtime +$DIAS -delete

# 3. monta o repositório
cd "$REPO" || { echo "$(agora) ERRO: repositório não encontrado" >> "$LOG"; exit 1; }
mkdir -p backups servidor/scripts servidor/cron

# limpa backups antigos (inclusive os da estrutura antiga, na raiz)
rm -f backups/*.tar.gz ./*.tar.gz ./world0.ksd ./docker-compose.yml

ls -1t "$BACKUPS"/world-"$hoje"-*.tar.gz 2>/dev/null | head -n "$HOJE_MAX" | xargs -r -I{} cp {} backups/
ls -1 "$DIARIOS"/dia-*.tar.gz 2>/dev/null | grep -v "dia-$hoje" | xargs -r -I{} cp {} backups/

# configuração do servidor, sem as senhas
sed -E 's/(PASSWORD=).*/\1SUA_SENHA_AQUI/' "$SERVIDOR/docker-compose.yml" > servidor/docker-compose.yml
cp /usr/local/bin/enshrouded-backup.sh /usr/local/bin/enshrouded-restart.sh servidor/scripts/ 2>/dev/null
cp /etc/cron.d/enshrouded-backup /etc/cron.d/enshrouded-restart servidor/cron/ 2>/dev/null

# trava de segurança: nunca publicar uma senha real
if grep -E 'PASSWORD=' servidor/docker-compose.yml | grep -qv 'SUA_SENHA_AQUI'; then
  echo "$(agora) ERRO: senha detectada no docker-compose, envio cancelado" >> "$LOG"
  exit 1
fi

# 4. commit único e envio
git checkout -q --orphan novo
git add -A
git commit -q -m "Backups - $(date '+%d/%m/%Y %H:%M')"
git branch -D main -q 2>/dev/null
git branch -m main
if git push -q -f origin main >> "$LOG" 2>&1; then
  echo "$(agora) enviado: $(ls backups/world-*.tar.gz 2>/dev/null | wc -l) de hoje + $(ls backups/dia-*.tar.gz 2>/dev/null | wc -l) dias anteriores" >> "$LOG"
else
  echo "$(agora) ERRO ao enviar ao GitHub (backup local ok)" >> "$LOG"
fi
