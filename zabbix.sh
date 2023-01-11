#!/bin/bash
# By Tra Viet
# Selinux and Firewall turn off before run this

#Set Time
timedatectl set-timezone Asia/Ho_Chi_Minh
timedatectl set-ntp 1

# Change hostname and add Domain
sed -i '2d' /etc/hosts
sed -i '2 i 127.0.1.1       zabbix' /etc/hosts
sed -i '3 i 127.0.1.1       zabbix.fptgroup.com' /etc/hosts
sed -i '4 i 10.10.100.161   zabbix.fptgroup.com' /etc/hosts
hostnamectl set-hostname zabbix

# Statics Ip set up
sed -i '5d' /etc/netplan/00-installer-config.yaml
sed -i '5 i \      addresses:' /etc/netplan/00-installer-config.yaml
sed -i '6 i \      - 10.10.100.161/24' /etc/netplan/00-installer-config.yaml
sed -i '7 i \      gateway4: 10.10.100.1' /etc/netplan/00-installer-config.yaml
sed -i '8 i \      nameservers:' /etc/netplan/00-installer-config.yaml
sed -i '9 i \        addresses:' /etc/netplan/00-installer-config.yaml
sed -i '10 i \        - 8.8.8.8' /etc/netplan/00-installer-config.yaml
sed -i '11 i \        - 10.10.100.100' /etc/netplan/00-installer-config.yaml
sed -i '12 i \        - 10.10.100.101' /etc/netplan/00-installer-config.yaml

sudo netplan apply

sleep 3

# Update && Upgrade Ubuntu
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install -y apache2 apache2-utils openssl snmp wget curl apt-transport-https fping
sudo apt install -y net-tools network-manager
sleep 3

#Install PHP for Zabbix
sudo apt install -y php php-{common,mysql,xml,xmlrpc,curl,gd,imagick,cli,dev,imap,mbstring,opcache,soap,zip,intl}
sudo apt install -y php php-{cgi,mbstring,net-socket,bcmath} libapache2-mod-php php-xml-util 

sleep 3

# Downloads Zabbix Repository
sudo wget https://repo.zabbix.com/zabbix/6.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.2-4%2Bubuntu22.04_all.deb
sudo dpkg -i zabbix-release_6.2-4+ubuntu22.04_all.deb
sudo apt update

sleep 3

# Zabbix Packages Install
sudo apt -y install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

sleep 3

# MariaDB Donwload and Install
# Version of MariaDB 10.X can run 6.X

sudo apt install software-properties-common -y
curl -LsS -O https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=10.7
sudo bash mariadb_repo_setup --mariadb-server-version=10.7
sudo apt update
sudo apt -y install mariadb-common mariadb-server mariadb-client
sudo systemctl enable mariadb
sudo systemctl start mariadb

sleep 3

# Configure Maria DB
# Type Y/n follow the question below
mysql_secure_installation <<EOF

y
y
zabbixfptgroup
zabbixfptgroup
y
y
y
y
EOF

# Set up Database for Zabbix
mysql -u root -p <<EOF
create database zabbix character set utf8mb4 collate utf8mb4_bin;
grant all privileges on zabbix.* to zabbix@localhost identified by 'zabbixfptgroup';
set global log_bin_trust_function_creators = 1;
Flush Privileges;
exit
EOF

sleep 3

# Get PHP for Zabbix
sudo apt-cache policy zabbix-server-mysql

sleep 3

# Import Structure of Zabbix database
sudo zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u zabbix -p'zabbixfptgroup' zabbix

# Configure DBHost, DBName, DBUser, DBPassword /etc/zabbix/zabbix_server.conf
sed -i 's/# DBHost=localhost/DBHost=localhost/g' /etc/zabbix/zabbix_server.conf
sed -i "s/DBName=zabbix/DBName=zabbix/g" /etc/zabbix/zabbix_server.conf
sed -i "s/DBUser=zabbix/DBUser=zabbix/g" /etc/zabbix/zabbix_server.conf
sed -i 's/# DBPassword=/DBPassword=zabbixfptgroup/g' /etc/zabbix/zabbix_server.conf
# Configure SNMP Ping
sed -i "s/# StartPingers=1/StartPingers=10/g" /etc/zabbix/zabbix_server.conf

# Configure PHP Zabbix

sed -i '20 i \        php_value date.timezone Asia/Ho_Chi_Minh' /etc/zabbix/apache.conf
sed -i '31 i \        php_value date.timezone Asia/Ho_Chi_Minh' /etc/zabbix/apache.conf

#Enable and restart Zabbix
sudo systemctl enable zabbix-server zabbix-agent apache2
sudo systemctl restart zabbix-server zabbix-agent apache2

sleep 3

# Set up SSL for HTTPS
sed -i '395 i [ zabbix.fptgroup.com ]' /etc/ssl/openssl.cnf
sed -i '396 i subjectAltName = DNS:zabbix.fptgroup.com' /etc/ssl/openssl.cnf

sleep 3
# Generate SSL Key
openssl genrsa -aes128 2048 > /etc/ssl/private/zabbix.key
openssl rsa -in /etc/ssl/private/zabbix.key -out /etc/ssl/private/zabbix.key
openssl req -utf8 -new -key /etc/ssl/private/zabbix.key -out /etc/ssl/private/zabbix.csr << EOF

VN
Ho Chi Minh
Ho Chi Minh
FPTGroup
zabbix
zabbix.fptgroup.com
zabbix@zabbix.fptgroup.com
zabbixfptgroup
FPTGroup
EOF

openssl x509 -in /etc/ssl/private/zabbix.csr -out /etc/ssl/private/zabbix.crt -req -signkey /etc/ssl/private/zabbix.key -extfile /etc/ssl/openssl.cnf -extensions zabbix.fptgroup.com -days 3650
chmod 644 /etc/ssl/private/zabbix.key

sleep 3

# Create VirtualHost for Zabbix website
# DocumentRoot point to Zabbix Website
sudo cat << EOF > /etc/apache2/sites-available/zabbix.fptgroup.com.conf 
<VirtualHost *:80> 
    ServerName zabbix.fptgroup.com
    ServerAlias www.zabbix.fptgroup.com
    Redirect permanent / https://zabbix.fptgroup.com
</VirtualHost>

<VirtualHost *:443>

    ServerName zabbix.fptgroup.com
    ServerAlias www.zabbix.fptgroup.com
    ServerAdmin admin@zabbix.fptgroup.com
    DocumentRoot /usr/share/zabbix

    ErrorLog ${APACHE_LOG_DIR}/www.zabbix.fptgroup.com_error.log
    CustomLog ${APACHE_LOG_DIR}/www.zabbix.fptgroup.com_access.log combined

    SSLEngine on
    SSLCertificateFile /etc/ssl/private/zabbix.crt
    SSLCertificateKeyFile /etc/ssl/private/zabbix.key

   <Directory /usr/share/zabbix>
      Options FollowSymlinks
      AllowOverride All
      Require all granted
   </Directory>

</VirtualHost>
EOF

sleep 3

# Change default apache and enable SSL
sudo a2enmod ssl
sudo a2dissite 000-default.conf
sudo a2ensite zabbix.fptgroup.com.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
sleep 3

# Allow Firewall Port Forward
sudo ufw allow proto tcp from any to any port 10050,10051,80,443,22,161
sudo ufw allow proto tcp from 10.10.100.164 to any port 5665
sudo ufw allow proto tcp from 10.10.100.162 to any port 9115
sudo ufw enable

# Change Password user
sudo passwd user <<EOF
Fpt@@123
Fpt@@123
EOF

cd

rm -rf zabbix
