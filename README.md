# Claude Desktop no Linux Mint

Script que instala o **Claude Desktop (beta para Linux)** no Linux Mint pelo repositório apt oficial da Anthropic e deixa o **Cowork** pronto para usar.

Baseado na documentação oficial: <https://code.claude.com/docs/en/desktop-linux>

## Requisitos

| Item | Mínimo |
|---|---|
| Sistema | Linux Mint 21+ (base Ubuntu 22.04+), Ubuntu 22.04+ ou Debian 12+ |
| Arquitetura | amd64 ou arm64 |
| Cowork | Virtualização (VT-x / AMD-V) ativada na BIOS/UEFI |

O Mint 20 (base Ubuntu 20.04) não é compatível: o pacote exige `libc6 >= 2.34`.

## Como executar

```bash
git clone https://github.com/sauloprado/claude-desktop-mint.git
cd claude-desktop-mint
bash instalar-claude-desktop.sh
```

Rode como seu usuário normal, **sem sudo**: o script pede a senha só quando precisa.

Para instalar só o app, sem preparar o Cowork:

```bash
bash instalar-claude-desktop.sh --sem-cowork
```

Pode rodar de novo quantas vezes quiser: o script é idempotente.

## O que o script faz

| Etapa | Na prática |
|---|---|
| Checagens | Bloqueia root, valida arquitetura e a base do Mint/Ubuntu/Debian |
| Dependências | Instala `curl`, `gnupg` e `ca-certificates` |
| Chave | Baixa a chave da Anthropic e confere o fingerprint `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE` (aborta se não bater) |
| Repositório | Registra `downloads.claude.ai/claude-desktop/apt/stable` em `/etc/apt/sources.list.d/claude-desktop.list` |
| Instalação | `apt install claude-desktop` com os pacotes recomendados |
| Login salvo | Garante o `gnome-keyring` (Cinnamon/GNOME) |
| Cowork | Instala QEMU + OVMF (+ `virtiofsd`), adiciona o usuário ao grupo `kvm` e carrega o módulo `vhost_vsock` agora e em todo boot |

## Depois da instalação

1. Se o script avisar, faça **logout e login** (grupo `kvm`).
2. Abra **Claude** pelo menu ou rode `claude-desktop`.
3. Entre com sua conta (claude.ai ou SSO da organização).

## Atualizar e remover

```bash
# atualizar (chega junto com as atualizações do sistema)
sudo apt update && sudo apt upgrade

# remover
sudo apt remove claude-desktop
sudo rm -f /etc/apt/sources.list.d/claude-desktop.list
```

## Problemas comuns

| Mensagem | Solução |
|---|---|
| `Unable to locate package claude-desktop` | `sudo apt update` e confira `cat /etc/apt/sources.list.d/claude-desktop.list` |
| `NO_PUBKEY BAA929FF1A7ECACE` | Rode o script de novo para baixar a chave |
| Login não fica salvo | `sudo apt install gnome-keyring` e desbloqueie o chaveiro |
| Cowork requires KVM | Ative a virtualização na BIOS/UEFI |
| Sem permissão em `/dev/kvm` | Logout e login após entrar no grupo `kvm` |
| Cowork requires vhost_vsock | `sudo modprobe vhost_vsock` e reabra o app |

## Ainda não disponível no beta Linux

Computer Use, ditado por voz e (no Wayland) o atalho global do Quick Entry depende do portal do ambiente gráfico.

---

Projeto pessoal, sem vínculo com a Anthropic ou com o Linux Mint. Os nomes citados são marcas de seus respectivos donos.

**Autor:** Saulo Prado
