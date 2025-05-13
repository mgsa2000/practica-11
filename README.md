# practica-11

Implantación de Wordpress en AWS utilizando una arquitectura de tres niveles

contaremos con nuestro archivo .env que estaran guardadas nuestras variables asi como nuestro archivo load-balancer para que nuestro balanceador de carga vaya cambiando entre los dos frontend y necesitaremos nuestro archivo nfs para asignarle a nuestra direccion diferentes caracteristicas.

Vamos a usar 5 máquinas para esta práctica 
 maquina backend donde guardaremos nuestra base de datos mysql, dos maquinas frontend donde tendremos nuestros worpress compartidos a traves de NFS y que usaremos para que el balanceadore de cargar cambie entre los dos segun le parezca mejor

 Ahora pasamos al proceso de instalación.
 ## Máquina backend 
 Primero en la maquina backend instalaremos el lamp de la siguiente manera:

Cogemos las variables

```bash
source .env
```
Configuramos para mostrar los comandos y finalizar si hay error

```bash
set -ex
```
Actualizamos los repositorios

```bash
apt update
```
Actualizamos los paquetes

```bash
apt upgrade -y
```
Instalamos MySQL Server

```bash
apt install mysql-server -y
```
La diferencia de este lamp es que modificaremos las direccion de la  interfaz de red del servidor de MySQL se van a permitir conexiones

```bash
sed -i "s/127.0.0.1/$BACKEND_IP/" /etc/mysql/mysql.conf.d/mysqld.cnf
```

Reiniciamos mysql para que se haga los cambios
```bash
sudo systemctl restart mysql
```

Una vez que la pila lamp este instalada vamos a generar un deploy para mysql creando la base de datos y dandole permisos a los usuarios.

Configuramos para mostrar los comandos y finalizar si hay error

```bash
set -ex
```
Importamos el archivo de variables

```bash
source .env
```
Creamos  la base de datos de usuario

```bash
mysql -u root <<< "DROP DATABASE IF EXISTS $WORDPRESS_DB_NAME"
mysql -u root <<< "CREATE DATABASE $WORDPRESS_DB_NAME"
mysql -u root <<< "DROP USER IF EXISTS $WORDPRESS_DB_USER@$FRONTEND_IP"
mysql -u root <<< "CREATE USER $WORDPRESS_DB_USER@$FRONTEND_IP IDENTIFIED BY '$WORDPRESS_DB_PASSWORD'"
mysql -u root <<< "GRANT ALL PRIVILEGES ON $WORDPRESS_DB_NAME.* TO $WORDPRESS_DB_USER@$FRONTEND_IP"
```
## Máquina NFS server.
Aquí instalaremos un servidor NFS para poder compartir la carpeta html y asi poder instalar wordpress en los frontales.


Configuramos para mostrar los comandos y finalizar si hay error

```bash
set -ex
```
Importamos el archivo de variables

```bash
source .env
```
Instalamos el NFS server

```bash
apt install nfs-kernel-server -y
```
Como debemos el directorio que vamos a comparti en este caso /var/www/html

```bash
mkdir -p /var/www/html
```
Cambiamos los permisos para que cualquiera pueda leer , escribir en esa carpeta

```bash
chown nobody:nogroup /var/www/html
```
Exportamos nuestro archivo de configuracion

```bash
cp ../nfs/exports /etc/exports
```
Establecemos el rango que ip que podran montar nuestro directorio 

```bash
sed -i "s#FRONTEND_NETWORK#$FRONTEND_NETWORK#" /etc/exports
```
Reiniciamos el servicio de NFS

```bash
systemctl restart nfs-kernel-server
```

## Maquinas frontales.
Primero instalamos apache.
Configuramos para mostrar los comandos y finalizar si hay error
```bash
set -ex
```
Actualizamos los repositorios
```bash
apt update
```
Actualizamos los paquetes
```bash
apt upgrade -y
```
Instalamos el servidor web Apache
```bash
apt install apache2 -y
```
Habilitamos un módulo rewrite
```bash
a2enmod rewrite
```
Copiamos el arhcivo de configuracion de Apache
```bash
cp ../conf/000-default.conf /etc/apache2/sites-available
```
Instalamos PHP y algunos modulos de PHP para Apache y MySQL
```bash
apt install php libapache2-mod-php php-mysql -y
```
Reiniciamos el servicio de Apache
```bash
systemctl restart apache2
```
Copiamos el script de prueba de PHP en /var/www/html
```bash
cp ../php/index.php /var/www/html
```
Modificar el propietario y el grupo
```bash
chown -R www-data:www-data /var/www/html
```

Ahora instalamos el cliente NFS.

Configuramos para mostrar los comandos y finalizar si hay error
```bash
set -ex
```

Importamos las maquinas
```bash
source .env
```

Instalamos el NFS cliente
```bash
apt install nfs-common -y
```
```bash
sed -i "/LABEL=UEFI/a $NFS_SERVER_IP:/var/www/html /var/www/html  nfs auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0" /etc/fstab
```
reiniciamos el montador

```bash
systemctl daemon-reload
```
montamos nuestro disco

```bash
mount $NFS_SERVER_IP:/var/www/html /var/www/html
```
Por últimos,instalamos wordpress.

Configuramos para mostrar los comandos y finalizar si hay error
```bash
set -ex
```
Importamos el archivo de variables
```bash
source .env
```
Borramos intalaciones previas

```bash
rm -rf /tmp/wp-cli.phar*
```
Descargamos el WP-CLI , tambien se puede descargar con curl -o, la ruta /opt como lo vamos a usar mas de una vez , en caso de usarlo solo una vez es mejor en /tmp

```bash
wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -P /tmp
```
Le asignamos permisos de ejecucion

```bash
chmod +x /tmp/wp-cli.phar
```

Lo movemos con en los comandos locales /usr/local/bin y le asignamos un nombre mas corto, asi no tenemos que poner toda la ruta /tmp/wp-cli.phar

```bash
mv /tmp/wp-cli.phar /usr/local/bin/wp

rm -rf $WORDPRESS_DIRECTORY/*
```
Instalamos el codigo fuente, en español , en la ruta /var/www/html , y que se pueda ejercutar como root

```bash
wp core download --locale=es_ES --path=$WORDPRESS_DIRECTORY --allow-root
```
Creamos el archivo de configuracion

```bash
wp config create --dbname=$WORDPRESS_DB_NAME --dbuser=$WORDPRESS_DB_USER --dbpass=$WORDPRESS_DB_PASSWORD --dbhost=$BACKEND_IP --path=$WORDPRESS_DIRECTORY --allow-root
```
Instalamos el Worpres con el titulo y el usuario

```bash
wp core install --url=$LE_DOMAIN --title=$WORDPRESS_TITULO --admin_user=$WORDPRESS_USER --admin_password=$WORDPRESS_PASSWORD --admin_email=$LE_EMAIL --path=$WORDPRESS_DIRECTORY --allow-root  
```
 Cambiamos los permisos de root a www-data

```bash
chown www-data:www-data /var/www/html/*
```
Instalamos un tema

```bash
wp theme install mindscape --activate --path=$WORDPRESS_DIRECTORY --allow-root
```
Configuramos los enlaces 

```bash
wp rewrite structure '/%postname%/' --path=$WORDPRESS_DIRECTORY --allow-root
```
 Instalamos un plugin para que oculte el inicio de sesion

```bash
wp plugin install wps-hide-login --activate --path=$WORDPRESS_DIRECTORY --allow-root
```
Configuramos el plugin 

```bash
wp option update whl_page "$WORDPRESS_HIDE_LOGIN_URL" --path=$WORDPRESS_DIRECTORY --allow-root
```
Copiamos el archivo .htaccess

```bash
cp ../htaccess/.htaccess $WORDPRESS_DIRECTORY
```
Configuramos la variable $_SERVER['HTTPS'] , para que cargen las hojas de estilo CSS

```bash
sed -i "/COLLATE/a \$_SERVER['HTTPS'] = 'on';" /var/www/html/wp-config.php
```

Cambiamos los permisos de root a www-data

```bash
chown www-data:www-data /var/www/html/*
```
## maquina balancer.

Comando para ver la ejecucion y  si hay fallo pare
```bash
set -ex
```

Usamos nuestro archivo de variables

```bash
source .env
```

Actualizamos

```bash
apt update
apt upgrade -y
```

instalaccion de Nginx
```bash
sudo apt install nginx -y
```

vamos a deshabilitar el sitio por defecto eliminando el enlace simbólico:

```bash
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    unlink /etc/nginx/sites-enabled/default
fi
```

Colocamos el archivo balanceador en la carpeta de sitios disponibles

```bash
cp ../conf/load-balancer.conf /etc/nginx/sites-available/
```

Cambiamos los valores de IP_FRONTEND

```bash
sed -i "s/IP_FRONTEND_1/$FRONTEND_IP/" /etc/nginx/sites-available/load-balancer.conf
sed -i "s/IP_FRONTEND_2/$FRONTEND_IP2/" /etc/nginx/sites-available/load-balancer.conf
sed -i "s/LE_DOMAIN/$LE_DOMAIN/" /etc/nginx/sites-available/load-balancer.conf
```

Habilitamos el virtual host del balanceador de carga

```bash
if [ ! -f "/etc/nginx/sites-enabled/default" ]; then
    ln -s /etc/nginx/sites-available/load-balancer.conf /etc/nginx/sites-enabled/
fi
```

Recargue la configuración de Nginx.

```bash
sudo systemctl reload nginx
```
por ultimo,instalamos el certificado.
Configuramos para mostrar los comandos y finalizar si hay error

```bash
set -ex
```

Importamos el archivo de variables

```bash
source .env
```
El proveedor de donimnio sera no-ip

Instalamos y actualizamos snap

```bash
snap install core
snap refresh core
```
Eliminamos instalaciones previas de cerbot con apt

```bash
apt remove certbot -y
```
Instalamos Certbot

```bash
snap install --classic certbot
```
Solicitamos un cerficado a Let`s Encrypt

```bash
sudo certbot --apache -m $LE_EMAIL --agree-tos --no-eff-email -d $LE_DOMAIN --non-interactive
```
## comprobaciones
![](imagenes/111.png)


![](imagenes/222.png)