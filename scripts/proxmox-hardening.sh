#!/bin/bash

echo "--------------------------------------------------"
echo "      A Iniciar Proxmox Hardening & Setup...      "
echo "--------------------------------------------------"

# --- 1. Verificação de Segurança ---
echo "A verificar a versão do sistema..."

if ! grep -q "trixie" /etc/os-release; then
    echo "Erro: Este script é exclusivo para Proxmox VE 9.x (Debian Trixie)."
    exit 1
fi

echo "Versão compatível detetada."

# --- 2. Configurar Repositórios (No-Subscription) ---
echo "A configurar repositórios (No-Subscription)..."

# Faz backup da pasta dos repositórios
cp -r /etc/apt/sources.list.d /etc/apt/sources.list.d.bak

# Remove repositórios Enterprise (Pagos)
rm -f /etc/apt/sources.list.d/pve-enterprise.sources
rm -f /etc/apt/sources.list.d/ceph.sources

# Adiciona repositório Gratuito do Proxmox (Trixie)
echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# --- 3. Atualizar o Sistema ---
echo "A atualizar o sistema..."
apt update && apt dist-upgrade -y

# --- 4. Instalar Microcode (CPU Security) ---
echo "A verificar e instalar Microcode do CPU..."
if lscpu | grep -q "Intel"; then
    echo " -> Intel detetado. A instalar microcode..."
    apt install -y intel-microcode
elif lscpu | grep -q "AMD"; then
    echo " -> AMD detetado. A instalar microcode..."
    apt install -y amd64-microcode
fi

# --- 5. Remover Aviso "No Valid Subscription" ---
# Executado no fim para garantir persistência após updates
echo "A remover aviso de subscrição na UI..."
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid subscription'\),)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy.service

# --- 6. Limpeza Final ---
echo "A limpar ficheiros temporários..."
apt autoremove -y && apt autoclean

echo "----------------------------------------------------------"
echo "            Instalação concluída com sucesso!             "
echo "    Por favor reiniciar o servidor com o comando: reboot   "
echo "----------------------------------------------------------"