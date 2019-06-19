#!/bin/bash

set -e

until MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root  ; do
  >&2 echo "MySQL is unavailable - sleeping"
  sleep 3
done

# close bin log

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root \
-e "SET SQL_LOG_BIN=0;"

# create replication user

# mysql_net=$(ip route | awk '$1=="default" {print $3}' | sed "s/\.[0-9]\+$/.%/g")
mysql_net='172.29.0.%'

# 其他文章，此处不需要建立用户，只需授权用户即可，参考：https://www.cnblogs.com/kevingrace/p/10384691.html

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root \
-e "CREATE USER '${MYSQL_REPLICATION_USER}'@'${mysql_net}' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}'; \
GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'${mysql_net}';"


#开启日志
#设置master
#安装组复制插件
#设置ip白名单
#启动组复制


MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root \
-e "FLUSH PRIVILEGES; \
SET SQL_LOG_BIN=1; \
CHANGE MASTER TO MASTER_USER='${MYSQL_REPLICATION_USER}', MASTER_PASSWORD='${MYSQL_REPLICATION_PASSWORD}' \
FOR CHANNEL 'group_replication_recovery'; \
INSTALL PLUGIN group_replication SONAME 'group_replication.so'; \
set global group_replication_ip_whitelist='172.29.0.2,172.29.0.3,172.29.0.4,172.29.0.5,172.29.0.6'; \
set global group_replication_bootstrap_group=ON; \
start group_replication; \
set global group_replication_bootstrap_group=OFF;"