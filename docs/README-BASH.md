# a11yctl CLI - Versão Bash

CLI para o projeto **a11yctl** em Bash, compatível com:
- **macOS** (Intel e Apple Silicon)
- **Debian** / **Ubuntu** / Distribuições Linux baseadas em Debian
- **Outras distribuições Linux** (com bash)

## Instalação Rápida

### macOS

```bash
curl -fsSL https://raw.githubusercontent.com/A11yDevs/a11yctl/main/install.sh | bash
```

Ou diretamente:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/A11yDevs/a11yctl/main/install.sh)
```

### Linux (Debian/Ubuntu)

```bash
curl -fsSL https://raw.githubusercontent.com/A11yDevs/a11yctl/main/install.sh | bash
```

Ou:

```bash
wget -O - https://raw.githubusercontent.com/A11yDevs/a11yctl/main/install.sh | bash
```

## Instalação Manual

### 1. Clone ou baixe o repositório

```bash
git clone https://github.com/A11yDevs/a11yctl.git
cd a11yctl/cli
```

### 2. Execute o instalador

```bash
bash install.sh
```

O script automaticamente:
- Detecta seu SO (macOS, Linux)
- Baixa os arquivos necessários
- Instala em `/usr/local/bin` ou `~/.local/bin`
- Configura o PATH se necessário

### 3. Verifique a instalação

```bash
a11yctl --version
a11yctl help
```

## Uso

### Modo Interativo Acessível

Quando você executa `a11yctl` sem argumentos no host, a CLI abre o modo interativo:

```text
a11yctl - modo interativo

Digite help para ver comandos.
Digite exit para sair.

a11yctl>
```

Contextos disponíveis:

- `a11yctl>`
- `a11yctl vm>`
- `a11yctl vm config>`
- `a11yctl vm host-share>`
- `a11yctl host>`

Comandos globais em qualquer contexto:

- `help` e `?`
- `back`
- `status`
- `clear`
- `exit` e `quit`

Observações:

- O modo interativo é textual e compatível com leitores de tela.
- O modo direto continua funcionando igual.
- Ações sensíveis pedem confirmação com padrão negativo `[s/N]`.

### Comandos Principais

#### Ajuda

```bash
a11yctl help
a11yctl -h
```

#### Versão

```bash
a11yctl version
a11yctl --version
a11yctl version --check-update  # Verifica se há atualizações disponíveis
```

#### Auto-Atualização

```bash
a11yctl self-update              # Atualiza se houver nova versão
a11yctl update --force           # Força atualização
```

### Exemplos no modo interativo

```text
$ a11yctl
a11yctl> vm
a11yctl vm> status
a11yctl vm> start --headless
a11yctl vm> config
a11yctl vm config> show
a11yctl vm config> back
a11yctl vm> host-share
a11yctl vm host-share> list
a11yctl vm host-share> back
a11yctl vm> back
a11yctl> host
a11yctl host> install
a11yctl host> exit
```

Comandos completos também funcionam no prompt interativo:

```text
a11yctl> vm status
a11yctl> vm start --headless
a11yctl> vm config show
```

### Gerenciamento de VM

#### Listar VMs

```bash
a11yctl vm list
```

#### Iniciar VM

```bash
a11yctl vm start

# Com nome específico
a11yctl vm start -n debian-a11y

# Modo headless (sem GUI)
a11yctl vm start --headless
```

#### Parar VM

```bash
a11yctl vm stop

# Parar com força
a11yctl vm stop -f

# Após timeout
a11yctl vm close -t 30
```

#### Remover VM

```bash
# Remove apenas registro/estado local da VM
a11yctl vm remove -n debian-a11y

# Remove tambem disco de dados (/home)
a11yctl vm remove -n debian-a11y --data --yes

# Remove tambem imagem de sistema
a11yctl vm remove -n debian-a11y --system --yes

# Remocao completa (registro + dados + sistema)
a11yctl vm remove -n debian-a11y --all --yes
```

#### Status da VM

```bash
a11yctl vm status
a11yctl vm status -q  # Status abreviado
```

#### Diagnóstico

```bash
a11yctl vm diagnose
```

#### Conectar via SSH

```bash
# Conexão padrão
a11yctl vm ssh

# Usuário e porta personalizados
a11yctl vm ssh -u a11ydevs -p 2222

# Com argumentos adicionais para SSH
a11yctl vm ssh -- -v
```

#### Pastas Compartilhadas

```bash
# Ver configuração atual
a11yctl vm host-share list

# Unix/macOS: compartilhar via SSH
a11yctl vm host-share set --mode ssh --ssh-user "$USER" --ssh-path "$HOME"

# Windows host (via Bash): compartilhar via CIFS
a11yctl vm host-share set --mode cifs --smb-server 10.0.2.2 --smb-share Users --smb-user "$USER" --smb-password '<senha>'

# Limpar configuração
a11yctl vm host-share clear
```

#### Instalar VM Release

```bash
a11yctl vm install

# Com argumentos adicionais
a11yctl vm install -n debian-a11y --no-gui
```

#### Configuração de runtime do QEMU

```bash
# Mostrar configuração efetiva atual
a11yctl vm config show

# Caminho do arquivo de configuração
a11yctl vm config path

# Resetar para defaults seguros
a11yctl vm config reset
```

Arquivo usado:

```text
~/.a11yctl/qemu/config.env
```

#### Otimização automática (com backup)

```bash
# Aplica perfil otimizado por sistema operacional host
a11yctl vm optimize

# Depois confira o resultado
a11yctl vm config show
```

O comando `optimize` cria backup automático de `config.env` antes de alterar os valores.

Perfil aplicado (base):

- Linux host: `-enable-kvm`, `-cpu host`, `-smp 4`, `-m 4096`
- macOS host: `-accel hvf`, `-cpu host`, `-smp 4`, `-m 4096`
- Windows host (bash): `-accel whpx`, `-smp 4`, `-m 4096`

Além disso, aplica defaults de baixa latência para I/O:

- `-drive ... if=virtio,cache=writeback,discard=unmap`
- `-device virtio-net-pci`
- `-device virtio-vga`

### Desinstalar CLI

```bash
# Remove apenas a CLI instalada
a11yctl uninstall --yes

# Remove CLI e todo estado local (VMs, discos e logs)
a11yctl uninstall --purge-state --yes
```

## Configuração Padrão

| Opção | Valor Padrão |
|-------|--------------|
| VM | debian-a11y |
| Usuário SSH | a11ydevs |
| Porta SSH | 2222 |

Observacao: a CLI e QEMU-only; a opcao de backend foi removida.

## Estrutura de Diretórios

A CLI cria e utiliza os seguintes diretórios:

```
~/.a11yctl/
  ├── debian-a11ydevs.qcow2        # Imagem de sistema QEMU
  ├── debian-a11y-home.qcow2       # Disco de dados (montado em /home)
  └── qemu/                        # Estados das VMs QEMU
      └── <vm-name>.json
```

## Requisitos

### macOS
- bash 4.0+ (incluso no sistema)
- curl ou wget
- QEMU
- OpenSSH (incluso no sistema)

### Linux
- bash 4.0+
- curl ou wget
- QEMU
- OpenSSH
- qemu-system-x86_64 (para QEMU)

### Instalação de Requisitos

#### macOS
```bash
# Usando Homebrew
brew install qemu              # Para QEMU
```

#### Debian/Ubuntu
```bash
sudo apt-get update
sudo apt-get install -y \
    qemu-system-x86 \
    qemu-utils \
    openssh-client \
    curl
```

## Troubleshooting

### "Comando não encontrado"

Se após instalar você receber "comando não encontrado", adicione ao seu shell rc:

**Para bash** (`~/.bashrc` ou `~/.bash_profile`):
```bash
export PATH="$PATH:$HOME/.local/bin"
# ou
export PATH="$PATH:/usr/local/bin"
```

**Para zsh** (`~/.zshrc`):
```bash
export PATH="$PATH:$HOME/.local/bin"
```

### Problemas de Permissão

```bash
# Verificar permissões
ls -la $(which a11yctl)

# Reparar permissões
chmod +x $(which a11yctl)
```

### Falha ao Baixar

Se houver problemas de conectividade ao GitHub:

1. Verifique sua conexão de internet
2. Tente usando a flag `--force`:
   ```bash
   a11yctl self-update --force
   ```
3. Instale manualmente seguindo os passos do repositório

## Desenvolvimento

### Executar localmente

```bash
# Clonar o repositório
git clone https://github.com/A11yDevs/a11yctl.git
cd a11yctl/cli

# Testar sem instalar
./a11yctl help
./a11yctl version

# Simular instalação
./install.sh
```

### Testes

```bash
# Executar suite de testes
cd ../tests
pytest -v

# Teste específico
pytest -v tests/test_*.py
```

## Compatibilidade

| OS | Status | Notas |
|-------|--------|-------|
| macOS 10.15+ | ✅ Suportado | Intel e Apple Silicon (M1+) |
| Ubuntu 20.04+ | ✅ Suportado | Debian 11+, Raspberry Pi OS |
| Debian 11+ | ✅ Suportado | |
| Fedora/CentOS | ⚠️ Parcial | Bash disponível, adapte comandos |
| Alpine Linux | ⚠️ Parcial | Verifique dependências (sh vs bash) |
| WSL (Windows) | ✅ Suportado | Como Linux (Ubuntu ou Debian) |

## Licença

GNU General Public License v3.0

Ver [LICENSE](../../LICENSE) para detalhes.

## Suporte

Para reportar problemas ou sugerir melhorias:
- [Issues do GitHub](https://github.com/A11yDevs/a11yctl/issues)
- [Discussions](https://github.com/A11yDevs/a11yctl/discussions)
