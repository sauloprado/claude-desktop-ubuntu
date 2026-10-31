#!/usr/bin/env bash
# =============================================================================
#  instalar-claude-desktop.sh
#  Instala o Claude Desktop (beta Linux) no Ubuntu, Linux Mint e Debian
#  pelo repositório apt OFICIAL da Anthropic
#  Projeto: https://github.com/sauloprado/claude-desktop-ubuntu
#  Fonte: https://code.claude.com/docs/en/desktop-linux
#
#  Uso:  bash instalar-claude-desktop.sh                (NÃO rode com sudo)
#        bash instalar-claude-desktop.sh --sem-cowork   (pula ajustes de VM)
#
#  O script é idempotente: pode ser executado de novo sem problemas.
# =============================================================================
set -euo pipefail

# ---------- Configuração (valores da documentação oficial) -------------------
KEY_URL="https://downloads.claude.ai/claude-desktop/key.asc"
KEY_FILE="/usr/share/keyrings/claude-desktop-archive-keyring.asc"
KEY_FPR="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
REPO_FILE="/etc/apt/sources.list.d/claude-desktop.list"
REPO_LINE="deb [arch=amd64,arm64 signed-by=${KEY_FILE}] https://downloads.claude.ai/claude-desktop/apt/stable stable main"

CONFIG_COWORK=1
[[ "${1:-}" == "--sem-cowork" ]] && CONFIG_COWORK=0

# ---------- Saída colorida ---------------------------------------------------
verde()   { printf '\e[32m✔ %s\e[0m\n' "$*"; }
amarelo() { printf '\e[33m⚠ %s\e[0m\n' "$*"; }
azul()    { printf '\n\e[1;34m▶ %s\e[0m\n' "$*"; }
erro()    { printf '\e[31m✖ %s\e[0m\n' "$*" >&2; exit 1; }

PRECISA_RELOGAR=0

# ---------- 1. Pré-checagens -------------------------------------------------
azul "Verificando o sistema"

[[ $EUID -eq 0 ]] && erro "Não rode como root/sudo. Execute como seu usuário: bash $0"
command -v apt-get >/dev/null && command -v dpkg >/dev/null \
  || erro "Sistema sem apt/dpkg. No Fedora use: https://github.com/sauloprado/claude-desktop-fedora"
command -v sudo >/dev/null || erro "sudo não encontrado."
sudo -v || erro "Não foi possível obter permissão de sudo."

ARCH="$(dpkg --print-architecture)"
[[ "$ARCH" == "amd64" || "$ARCH" == "arm64" ]] \
  || erro "Arquitetura '$ARCH' não suportada (apenas amd64 ou arm64)."
verde "Arquitetura: $ARCH"

# shellcheck disable=SC1091
. /etc/os-release
BASE="${UBUNTU_CODENAME:-${VERSION_CODENAME:-desconhecida}}"
echo "  Distribuição: ${PRETTY_NAME:-?}  (base: $BASE)"
case "$BASE" in
  focal|bionic|xenial|bullseye|buster)
    erro "Base '$BASE' é antiga demais (precisa libc6 >= 2.34). Use Ubuntu 22.04+, Mint 21+ ou Debian 12+." ;;
  *)
    verde "Base compatível" ;;
esac

# ---------- 2. Dependências (curl + gnupg) -----------------------------------
azul "Instalando dependências (curl, gnupg)"
sudo apt-get update -qq
sudo apt-get install -y curl gnupg ca-certificates >/dev/null
verde "curl e gnupg prontos"

# ---------- 3. Chave de assinatura da Anthropic ------------------------------
azul "Baixando e validando a chave de assinatura"
sudo curl -fsSLo "$KEY_FILE" "$KEY_URL" \
  || erro "Falha ao baixar a chave. Verifique se a rede alcança downloads.claude.ai."

FPR_BAIXADO="$(gpg --show-keys --with-colons "$KEY_FILE" 2>/dev/null \
               | awk -F: '/^fpr/ {print $10; exit}')"
if [[ "$FPR_BAIXADO" != "$KEY_FPR" ]]; then
  sudo rm -f "$KEY_FILE"
  erro "Fingerprint inválido ('${FPR_BAIXADO:-vazio}'). Chave removida por segurança."
fi
verde "Fingerprint confere: $KEY_FPR"

# ---------- 4. Repositório apt -----------------------------------------------
azul "Registrando o repositório apt"
echo "$REPO_LINE" | sudo tee "$REPO_FILE" >/dev/null
verde "Repositório em $REPO_FILE"

# ---------- 5. Instalação ----------------------------------------------------
azul "Instalando o claude-desktop"
sudo apt-get update
# Mantém os pacotes recomendados: trazem QEMU/OVMF/virtiofsd usados pelo Cowork
sudo apt-get install -y claude-desktop
verde "Claude Desktop instalado: $(dpkg-query -W -f='${Version}' claude-desktop)"

# ---------- 6. Chaveiro (para o login ficar salvo) ---------------------------
azul "Verificando o chaveiro do sistema (login salvo)"
if [[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* ]]; then
  verde "KDE detectado — o KDE Wallet será usado"
else
  sudo apt-get install -y gnome-keyring >/dev/null
  verde "gnome-keyring presente (Cinnamon/GNOME)"
fi

# ---------- 7. Requisitos do Cowork (VM com QEMU/KVM) ------------------------
if [[ $CONFIG_COWORK -eq 1 ]]; then
  azul "Preparando requisitos do Cowork (QEMU + KVM)"

  # 7.1 Virtualização habilitada na BIOS/UEFI?
  if grep -Eq '(vmx|svm)' /proc/cpuinfo; then
    verde "CPU com suporte a virtualização"
  else
    amarelo "Virtualização (VT-x/AMD-V) não detectada: ative na BIOS/UEFI para usar o Cowork."
  fi

  # 7.2 Pacotes QEMU/UEFI (normalmente já vêm como 'recommends')
  if [[ "$ARCH" == "amd64" ]]; then
    PKGS=(qemu-system-x86 ovmf)
  else
    PKGS=(qemu-system-arm qemu-efi-aarch64)
  fi
  # Ubuntu 22.04 (jammy) não tem virtiofsd; o app usa uma cópia embutida
  [[ "$BASE" != "jammy" ]] && PKGS+=(virtiofsd)
  sudo apt-get install -y "${PKGS[@]}" >/dev/null
  verde "Pacotes: ${PKGS[*]}"

  # 7.3 Grupo kvm (necessário também para /dev/vhost-vsock)
  if id -nG "$USER" | grep -qw kvm; then
    verde "Usuário '$USER' já está no grupo kvm"
  else
    sudo usermod -aG kvm "$USER"
    PRECISA_RELOGAR=1
    verde "Usuário '$USER' adicionado ao grupo kvm"
  fi

  # 7.4 Módulo vhost_vsock (agora e em todo boot)
  sudo modprobe vhost_vsock 2>/dev/null \
    && verde "Módulo vhost_vsock carregado" \
    || amarelo "Não foi possível carregar vhost_vsock (kernel sem suporte?)"
  echo vhost_vsock | sudo tee /etc/modules-load.d/vhost_vsock.conf >/dev/null
  verde "vhost_vsock configurado para carregar no boot"
fi

# ---------- 8. Resumo --------------------------------------------------------
azul "Concluído!"
echo "  • Abra pelo menu de aplicativos (Claude) ou rode: claude-desktop"
echo "  • Faça login com sua conta (claude.ai ou SSO da organização)"
echo "  • Atualizações chegam pelo apt: sudo apt update && sudo apt upgrade"
echo "  • Para remover: sudo apt remove claude-desktop && sudo rm -f $REPO_FILE"
if [[ $PRECISA_RELOGAR -eq 1 ]]; then
  amarelo "Faça LOGOUT e LOGIN de novo (ou reinicie) para o grupo kvm valer e o Cowork funcionar."
fi
