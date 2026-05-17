# a11yctl

CLI oficial do projeto A11yDevs para instalar, atualizar e operar a VM acessivel.

O comando principal agora e a11yctl. O comando legado ea11ctl continua disponivel temporariamente como alias de compatibilidade e mostra um aviso de depreciacao antes de delegar para a11yctl.

## Instalacao

No Windows PowerShell:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
iex (iwr 'https://raw.githubusercontent.com/A11yDevs/a11yctl/main/install.ps1' -UseBasicParsing).Content
```

O instalador baixa os arquivos publicados na raiz deste repositorio para ~/.a11yctl/bin no Windows e adiciona esse diretorio ao PATH do usuario.

## Uso basico

```powershell
a11yctl help
a11yctl version --check-update
a11yctl vm install
a11yctl vm start
a11yctl vm status
a11yctl vm ssh
```

Compatibilidade temporaria:

```powershell
ea11ctl help
```

## Migracao do ea11ctl

O novo diretorio de estado da CLI e ~/.a11yctl.

Instalacoes antigas podiam manter estado, discos e configuracoes em ~/.emacs-a11y-vm. Esta versao oferece migracao explicita:

```powershell
a11yctl migrate
a11yctl migrate-state
```

Regras da migracao:

- Detecta ~/.emacs-a11y-vm e copia o conteudo para ~/.a11yctl.
- Nunca apaga automaticamente ~/.emacs-a11y-vm.
- Nunca sobrescreve arquivos existentes no destino.
- Em conflito de nome, grava o arquivo copiado com sufixo .migrated antes da extensao.

O instalador tambem detecta o diretorio legado e tenta migrar os dados automaticamente, preservando a instalacao antiga.

## Diretorio de estado

Agora a CLI usa ~/.a11yctl para armazenar:

- imagem de sistema da VM
- discos persistentes de dados
- estado do QEMU em qemu/
- logs e configuracao de runtime

O diretorio legado ~/.emacs-a11y-vm continua sendo consultado apenas para fins de migracao.

## Self-update

Para atualizar a CLI instalada localmente:

```powershell
a11yctl self-update
```

O self-update baixa os arquivos diretamente da raiz de A11yDevs/a11yctl e atualiza:

- a11yctl.ps1
- a11yctl.cmd
- ea11ctl.ps1
- ea11ctl.cmd
- install.ps1
- VERSION

## Compatibilidade com ea11ctl

Durante esta fase de migracao, ea11ctl continua funcional apenas como wrapper de compatibilidade. O comportamento real da CLI esta em a11yctl.ps1.