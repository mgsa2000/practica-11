#!/bin/bash

# Configuramos para mostrar los comandos y finalizar si hay error
set -ex

# Importamos el archivo de variables
source .env

# Instalamos el NFS server
apt install nfs-kernel-server -y

# Como debemos el directorio que vamos a comparti en este caso /var/www/html
mkdir -p /var/www/html

# Cambiamos los permisos para que cualquiera pueda leer , escribir en esa carpeta
chown nobody:nogroup /var/www/html

# Exportamos nuestro archivo de configuacion 
cp ../nfs/exports /etc/exports

# Establecemos el rango que ip que podran montar nuestro directorio 
sed -i "s#FRONTEND_NETWORK#$FRONTEND_NETWORK#" /etc/exports

# Reiniciamos el servicio de NFS
systemctl restart nfs-kernel-server