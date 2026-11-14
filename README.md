# 🏰 Taverna da Guilda — Servidor de Enshrouded

Servidor dedicado de **Enshrouded 1.0** rodando em Docker numa VPS Linux, com atualização, backup e restart automáticos.

Este repositório guarda:

- a **configuração completa** do servidor, pronta para subir em qualquer VPS;
- os **backups do mundo**, enviados automaticamente a cada 30 minutos.

---

## 📁 Estrutura do repositório

```
.
├── README.md
├── backups/
│   ├── world-AAAAMMDD-HHMM.tar.gz   # 5 backups mais recentes de hoje
│   └── dia-AAAAMMDD.tar.gz          # último backup de cada dia (30 dias)
└── servidor/
    ├── docker-compose.yml           # configuração do servidor (senhas removidas)
    ├── scripts/
    │   ├── enshrouded-backup.sh     # backup local + envio para o GitHub
    │   └── enshrouded-restart.sh    # restart inteligente (só se estiver vazio)
    └── cron/
        ├── enshrouded-backup        # agendamento do backup
        └── enshrouded-restart       # agendamento dos restarts
```

Tudo dentro de `servidor/` é atualizado automaticamente pelo script de backup. Se a configuração do servidor mudar, o repositório acompanha.

---

## 🎮 Como entrar no servidor

1. Abra o Enshrouded e clique em **Entrar**
2. No filtro da direita, ative **Mostrar servidores dedicados**
3. Pesquise por **Taverna da Guilda**
4. Entre com a senha do seu cargo (peça no grupo)

> Servidor apenas para PC (Steam).

---

## 🖥️ Requisitos da VPS

| Item | Mínimo | Observação |
|---|---|---|
| CPU | 4 vCPUs **rápidas** | O servidor depende muito da velocidade por núcleo. Evite processadores antigos (ex.: Xeon E5) |
| RAM | 8 GB | Mais um swap de 4 GB por segurança |
| Disco | 30 GB | NVMe de preferência |
| Sistema | Ubuntu 24.04 | Com kernel **6.14 ou mais novo** para usar o ntsync |
| Rede | Porta **15637/UDP** aberta | É a única porta que o jogo usa |

> ⚠️ Fuja de VPS com **CPU steal** alto (coluna `st` do `vmstat`). Acima de 5% o servidor trava.

---

## 🚀 Instalação do zero

Todos os comandos rodam como `root` na VPS.

### 1. Preparar o sistema

```bash
apt update && apt upgrade -y
```

**Firewall** (libera SSH e a porta do jogo):

```bash
ufw allow OpenSSH && ufw allow 15637/udp && ufw --force enable
```

**Swap de 4 GB:**

```bash
fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

### 2. Kernel novo + ntsync (importante para o desempenho)

O servidor roda no Linux através do **Wine**. Sem o ntsync, o processo `wineserver` vira um gargalo e o servidor fica cerca de **3x mais lento** (aqui caiu de ~17 ms para ~6 ms por ciclo).

```bash
apt install -y linux-generic-hwe-24.04 && reboot
```

Depois do reboot:

```bash
uname -r   # precisa ser 6.14 ou maior
modprobe ntsync && echo ntsync > /etc/modules-load.d/ntsync.conf && ls /dev/ntsync
```

> Se o kernel não chegar ao 6.14, remova o bloco `devices:` do `docker-compose.yml`. O servidor funciona, só que mais pesado.

### 3. Docker

```bash
apt install -y docker.io docker-compose-v2 git
```

> Se a hospedagem já instala o Docker (confira com `docker --version`), pule este passo.

### 4. Baixar a configuração deste repositório

```bash
git clone https://github.com/lockade/enshrouded.git /root/enshrouded-github
mkdir -p /opt/enshrouded-server/game /root/enshrouded-backups
cp /root/enshrouded-github/servidor/docker-compose.yml /opt/enshrouded-server/
chown 4711:4711 /opt/enshrouded-server/game
```

O `chown` é obrigatório: o container roda com o usuário `4711` e, sem ele, o servidor falha com o erro `state is 0x202`.

### 5. Definir as senhas

```bash
nano /opt/enshrouded-server/docker-compose.yml
```

Troque todos os `SUA_SENHA_AQUI` pelas senhas reais. Os cargos são:

| Cargo | Permissões |
|---|---|
| **Admin** | Tudo, inclusive expulsar e banir jogadores |
| **Amigos** | Construir, editar a base e abrir baús. Não pode banir |

> O Enshrouded não usa uma senha única de servidor: **cada cargo tem a sua senha**, e quem entra com ela recebe as permissões daquele cargo.

### 6. Subir o servidor

```bash
cd /opt/enshrouded-server
docker compose up -d
docker compose logs -f
```

Na primeira vez ele baixa o servidor pela Steam, o que leva alguns minutos. Quando aparecer `'HostOnline' (up)!`, saia do log com `Ctrl+C` (o servidor continua rodando).

### 7. Restaurar o mundo a partir de um backup

Escolha um arquivo em `backups/` (por exemplo, o `dia-` mais recente) e:

```bash
cd /opt/enshrouded-server
docker compose down
rm -rf game/server/savegame
tar xzf /root/enshrouded-github/backups/dia-AAAAMMDD.tar.gz -C game/server
chown -R 4711:4711 game/server/savegame
docker compose up -d
```

### 8. Instalar as rotinas automáticas

```bash
cp /root/enshrouded-github/servidor/scripts/*.sh /usr/local/bin/
chmod +x /usr/local/bin/enshrouded-*.sh
cp /root/enshrouded-github/servidor/cron/* /etc/cron.d/
systemctl is-active cron
```

### 9. Ligar o envio de backups para o GitHub

A VPS precisa de uma chave própria para enviar ao repositório (uma **deploy key**, que só tem acesso a este repositório).

```bash
ssh-keygen -t ed25519 -f ~/.ssh/github_backup -N "" -C "vps-enshrouded-backup"
cat ~/.ssh/github_backup.pub
```

No GitHub: **repositório → Settings → Deploy keys → Add deploy key**. Cole a chave e marque **Allow write access**.

De volta na VPS:

```bash
printf "Host github.com\n  IdentityFile ~/.ssh/github_backup\n  IdentitiesOnly yes\n" >> ~/.ssh/config
ssh -T git@github.com    # deve responder "successfully authenticated"
cd /root/enshrouded-github
git remote set-url origin git@github.com:lockade/enshrouded.git
git config --global user.name "VPS Enshrouded"
git config --global user.email "vps@enshrouded.local"
```

Teste o primeiro envio:

```bash
/usr/local/bin/enshrouded-backup.sh && tail -2 /var/log/enshrouded-backup.log
```

---

## ⚙️ Rotinas automáticas

| Rotina | Quando (Brasília) | O que faz |
|---|---|---|
| **Atualização** | a cada 30 min | Atualiza o jogo, só se não houver ninguém online (feito pela própria imagem) |
| **Backup** | a cada 30 min | Salva o mundo localmente e envia para o GitHub |
| **Restart** | :15 e :45 | Reinicia só se o servidor estiver vazio |
| **Restart forçado** | 05:05 | Reinicia mesmo com gente online, 1x por dia |

**Por que reiniciar?** Com o tempo o servidor acumula entidades que não descarrega (já vimos subir de ~25 mil para ~70 mil), e o desempenho cai. O restart limpa isso em menos de um minuto, e o mundo é salvo antes de desligar.

### Retenção dos backups

| Onde | O que fica guardado |
|---|---|
| VPS (`/root/enshrouded-backups/`) | Todos os backups de 30 em 30 min dos últimos 7 dias |
| VPS (`/root/enshrouded-backups/diarios/`) | O último backup de cada dia, por 30 dias |
| GitHub (`backups/`) | Os 5 mais recentes de hoje + 1 por dia dos últimos 30 dias |

O repositório guarda **um único commit**, recriado a cada envio. Assim ele não cresce para sempre: os próprios nomes dos arquivos são o histórico.

Os backups não incluem a pasta `savegame/backup/` (cópias internas do jogo), porque ela é redundante com o nosso histórico e triplicaria o tamanho dos arquivos.

---

## 🛠️ Comandos úteis

Rode sempre de dentro de `/opt/enshrouded-server`.

| Para... | Comando |
|---|---|
| Ver o log ao vivo | `docker compose logs -f` |
| Reiniciar o servidor do jogo | `docker compose exec enshrouded supervisorctl restart enshrouded-server` |
| Forçar atualização (derruba quem estiver online) | `docker compose exec enshrouded supervisorctl start enshrouded-force-update` |
| Ver quantos jogadores estão online | `enshrouded-restart.sh --teste` |
| Reiniciar mesmo com gente online | `enshrouded-restart.sh --forcar` |
| Ver uso de CPU e RAM | `docker stats enshrouded` |
| Ver o histórico de restarts | `tail -20 /var/log/enshrouded-restart.log` |
| Ver o histórico de backups | `tail -20 /var/log/enshrouded-backup.log` |

> O Enshrouded **não tem comandos de admin nem console**. Expulsar e banir é feito dentro do jogo, por quem entrou com a senha de Admin.

### Medir o desempenho

```bash
docker compose logs --since 10m | grep "ecss] Stats" | sed -E 's/.*\| [0-9-]+ ([0-9:]+)\.[0-9]+ .*Upd:([0-9,]+).*Max:([0-9]+ms).*Avg:([0-9.]+ms).*Ent:([0-9,]+).*/\1  upd=\2  max=\3  avg=\4  ent=\5/'
```

| Indicador | Saudável | Problema |
|---|---|---|
| `upd` (atualizações por minuto) | ~3.500 | abaixo de 3.000 |
| `avg` (média por ciclo) | abaixo de 12 ms | acima de 16 ms |
| `max` (pior ciclo) | abaixo de 30 ms | acima de 50 ms |
| Avisos `Bad Performance` no log | nenhum | vários por minuto |

Os horários no log do Docker estão em **UTC** (3 horas a mais que Brasília).

---

## 🩺 Solução de problemas

**`Failed to initialize Steamworks system...Version Mismatch` / `No SteamUtils011`**
A versão Proton da imagem ainda não suporta o Steamworks do jogo. Use a tag `stable-wine` no `docker-compose.yml`.

**`Error! App '2278520' state is 0x202 after update job`**
Permissão errada na pasta do jogo ou falta de disco. Rode `chown -R 4711:4711 /opt/enshrouded-server/game` e confira com `df -h`.

**O servidor não aparece na lista do jogo**
Confira se o filtro **Mostrar servidores dedicados** está ligado, se o nome está escrito igual ao `SERVER_NAME` e se a porta **15637/UDP** está liberada no firewall da VPS **e** no da hospedagem.

**Lag para todo mundo**
Meça o desempenho (seção acima). Se estiver ruim:
1. Veja se as entidades (`ent`) estão muito altas → reinicie o servidor.
2. Rode `vmstat 1 30` e olhe a coluna `st` → se passar de 5%, a hospedagem está roubando CPU (abra chamado ou troque de VPS).
3. Rode `top -H` → se o `wineserver` estiver entre os mais pesados, confira se o ntsync está ativo (`ls /dev/ntsync`).

**Um jogador cai sozinho**
Se o servidor não reiniciou e só uma pessoa caiu, quase sempre é a internet dela. No log aparece `Congestion detected` com `rtt` alto, seguido de `Timeout for peer`. Peça para ela jogar no cabo e rodar um `ping -t` no IP do servidor.

**Erro de versão ao entrar**
O cliente e o servidor precisam estar na mesma versão. Atualize o jogo na Steam e, se precisar, force a atualização do servidor (seção de comandos).
