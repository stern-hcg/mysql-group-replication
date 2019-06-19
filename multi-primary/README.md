## 

```
docker-compose.yaml 配置的是多主的组复制集群

docker-compose up 

#当前项目init-master.sh, init-node.sh 脚本中执行了相关SQL，但是集群无法正常生效
需要手工执行相关的一些SQL



#连接到节点
docker exec -it mgr-node-0 /bin/bash 

#进入数据库
mysql -u root -p
node_root_pwd

第一个节点上重新执行的SQL如下：
set global group_replication_bootstrap_group=ON; \
start group_replication; \

从节点上重新执行的SQL如下：
set global group_replication_allow_local_disjoint_gtids_join=ON; \
start group_replication;



#脚本中执行的全部SQL如下
主节点：
SET SQL_LOG_BIN=0; \
CREATE USER 'replication'@'172.29.0.%' IDENTIFIED BY 'replication_pwd'; \
GRANT REPLICATION SLAVE ON *.* TO 'replication'@'172.29.0.%';
SET SQL_LOG_BIN=1; \
CHANGE MASTER TO MASTER_USER='replication', MASTER_PASSWORD='replication_pwd' FOR CHANNEL 'group_replication_recovery'; \
INSTALL PLUGIN group_replication SONAME 'group_replication.so'; \
set global group_replication_ip_whitelist='172.29.0.2,172.29.0.3,172.29.0.4,172.29.0.5,172.29.0.6'; \
set global group_replication_bootstrap_group=ON; \
start group_replication; \
set global group_replication_bootstrap_group=OFF;


查看相关节点状态：

SELECT * FROM performance_schema.replication_group_members;

测试组复制功能的自动容错：
docker network disconnect mysql-group-replication_mgr_cluster mgr-node-0
docker network connect mysql-group-replication_mgr_cluster mgr-node-0
提示：
2019-06-18T03:44:23.982720Z 0 [ERROR] Plugin group_replication reported: 'Member was expelled from the group due to network failures, changing member status to ERROR.'
stop group_replication;
start group_replication;

当前组中的主节点为节点2
SHOW STATUS LIKE 'group_replication_primary_member';



#节点状态为ERROR时候，可以尝试
stop group_replication;
reset master;
start group_replication;




#清除相关数据卷，完全重建相关容器
docker volume rm multi-primary_mgr-node-0-data multi-primary_mgr-node-1-data multi-primary_mgr-node-2-data

#过程中碰到的相关问题：
1. SET SQL_LOG_BIN=0, 需要关闭日志执行创建用户的操作，否则可能会造成从节点继续根据日志创建用户，无法创建成功（因为已经有一个了）
2. 单主模式下，需要配置
loose-group_replication_single_primary_mode = on
loose-group_replication_enforce_update_everywhere_checks = off
3. yaml文件中，如果使用锚点，注意其正确使用方法，docker-compose config 可以用来查看完整解析后的yaml文件
4. 从节点加入复制组之后，一直显示recovering， 原因是 create user ... 1396错误 这个操作一直执行失败，手工执行发现从节点处于super-readonly，
具体的原因暂时未确定。因为主节点创建的replication用户，应该是不记录日志的，不知道为什么仍然会同步到从节点。
5. 从节点报错'The member contains transactions not present in the group. 可以通过： 
set global group_replication_allow_local_disjoint_gtids_join=ON;
or
reset master 解决
6. 容器中应该配置开放33306端口，这个是组复制功能使用的，与3306数据库端口不一样。这个不打开，组复制功能一直提示其他的节点 connection refused 
7. 一定多看错误日志，错误日志会明确告知错误的原因




```