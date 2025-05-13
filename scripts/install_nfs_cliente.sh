#!/bin/bash
# Configuramos para mostrar los comandos y finalizar si hay error
set -ex

# Importamos las maquinas
source .env

# Instalamos el NFS cliente
apt install nfs-common -y

sed -i "/LABEL=UEFI/a $NFS_SERVER_IP:/var/www/html /var/www/html  nfs auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0" /etc/fstab

systemctl daemon-reload

mount $NFS_SERVER_IP:/var/www/html /var/www/html