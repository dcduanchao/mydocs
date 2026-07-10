# Docker 部署镜像

## redis

```bash
mkdir -p /root/redis/conf
mkdir -p /root/redis/data

cat > /root/redis/conf/redis.conf <<EOF
appendonly yes
protected-mode no #yes 保护模式
requirepass CHANGE_ME
logfile "6379.log"
EOF

docker run -d \
--name redis \
-p 6379:6379 \
-v /root/redis/data:/data \
-v /root/redis/conf/redis.conf:/etc/redis/redis.conf \
--restart=always \
redis:7 redis-server /etc/redis/redis.conf
```

## mysql8

```bash
mkdir -p /root/mysql/data
mkdir -p /root/mysql/log
mkdir -p /root/mysql/conf

# 配置优化
cat > /root/mysql/conf/my.cnf <<EOF
[mysqld]
innodb_buffer_pool_size = 2G
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
max_connections = 200
sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES

# 启用慢查询日志（调试性能瓶颈用）
#slow_query_log = 1
#slow_query_log_file = /var/log/mysql/slow.log
#long_query_time = 2

# 兼容性与严格性
#sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES

#
#SET autocommit=0;
#SET foreign_key_checks=0;
#SET unique_checks=0;

EOF

docker run -p 3306:3306 --name mysql \
-v /root/mysql/log:/var/log/mysql \
-v /root/mysql/data:/var/lib/mysql \
-v /root/mysql/conf/my.cnf:/etc/mysql/conf.d/my.cnf \
-e MYSQL_ROOT_PASSWORD=CHANGE_ME \
--restart=always \
-d mysql:8.0
```

验证配置：

```sql
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
SHOW VARIABLES LIKE 'max_connections';
SHOW VARIABLES LIKE 'sql_mode';
```

导出数据：

```bash
time docker exec mysql \
  sh -c 'exec mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" dc-test' > dump.sql
```

导入数据：

```bash
time docker exec -i mysql \
  sh -c 'exec mysql -u root -p"$MYSQL_ROOT_PASSWORD" dc-test' < dump.sql
```

拆分导入：

```bash
mkdir -p sql_parts
split -b 300M dump.sql sql_parts/part_

for file in sql_parts/part_*
do
  docker exec -i mysql sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" dc' < "$file"
done
```

### python 拆分脚本

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import argparse

def is_structure_start(stmt):
    stmt = stmt.strip().upper()
    return (
        stmt.startswith("DROP TABLE") or
        stmt.startswith("CREATE TABLE") or
        stmt.startswith("ALTER TABLE") or
        stmt.startswith("CREATE INDEX") or
        stmt.startswith("DROP INDEX")
    )

def is_data_statement(stmt):
    return stmt.strip().upper().startswith("INSERT INTO")

def split_sql_file(input_path, output_dir, max_size_mb):
    os.makedirs(output_dir, exist_ok=True)
    max_size = max_size_mb * 1024 * 1024

    schema_lines = []
    data_buffer = []
    part_index = 1
    current_size = 0
    statement_buffer = []

    with open(input_path, 'r', encoding='utf-8') as f:
        for line in f:
            statement_buffer.append(line)
            if ';' not in line:
                continue

            full_stmt = ''.join(statement_buffer).strip() + '\n'
            statement_buffer = []

            if is_structure_start(full_stmt):
                schema_lines.append(full_stmt)
                continue

            if is_data_statement(full_stmt):
                size = len(full_stmt.encode('utf-8'))
                if current_size + size > max_size and data_buffer:
                    write_part_file(output_dir, part_index, data_buffer)
                    part_index += 1
                    data_buffer = []
                    current_size = 0

                data_buffer.append(full_stmt)
                current_size += size
            else:
                if not data_buffer:
                    schema_lines.append(full_stmt)
                else:
                    data_buffer.append(full_stmt)

    if data_buffer:
        write_part_file(output_dir, part_index, data_buffer)
    if schema_lines:
        write_schema_file(output_dir, schema_lines)

def write_part_file(output_dir, index, content):
    filename = os.path.join(output_dir, f'part_{index:03d}.sql')
    with open(filename, 'w', encoding='utf-8') as f:
        f.writelines(content)
    print(f"写入数据文件: {filename}")

def write_schema_file(output_dir, content):
    filename = os.path.join(output_dir, 'schema.sql')
    with open(filename, 'w', encoding='utf-8') as f:
        f.writelines(content)
    print(f"写入结构文件: {filename}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="通用 SQL 拆分工具（支持非标准注释格式）")
    parser.add_argument("-i", "--input", required=True, help="SQL 输入文件路径")
    parser.add_argument("-o", "--output", default="sql_parts", help="输出目录")
    parser.add_argument("-s", "--size", type=int, default=300, help="数据每个文件最大大小 MB")
    args = parser.parse_args()

    split_sql_file(args.input, args.output, args.size)
```

```bash
python3 split_sql_by_size_struct_separate.py \
  -i dump.sql \
  -o sql_parts \
  -s 300
```

- `-i dump.sql`：原始 SQL 文件
- `-o sql_parts`：输出文件夹，会自动创建
- `-s 300`：每个文件最大 300MB

```bash
time docker exec mysql \
  sh -c 'exec mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" dc' > dump.sql

docker exec -i mysql sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" dc' < /root/sql-dump-splitter/sql_parts/schema.sql

for file in /root/sql-dump-splitter/sql_parts/part_*
do
  time docker exec -i mysql sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" dc' < "$file"
done

# 不是 docker 运行
mysql -u root -p your_db < sql_parts/schema.sql

for f in sql_parts/part_*.sql; do
  echo "导入 $f..."
  mysql -u root -p your_db < "$f"
done
```

## 图片库

```bash
mkdir -p /root/chevereto/images
sudo chown -R 33:33 /root/chevereto/images

docker run -d --name chevereto -p 7070:80 \
 -v /root/chevereto/images:/var/www/html/images \
 -e CHEVERETO_DB_HOST=mysql \
 -e CHEVERETO_DB_NAME=chevereto \
 -e CHEVERETO_DB_USER=root \
 -e CHEVERETO_DB_PASS=CHANGE_ME \
 --link mysql:mysql \
 --restart=always \
 ghcr.io/chevereto/chevereto:latest
```

## zk

```bash
mkdir -p /root/zookeeper/{data,datalog,conf}

cat > /root/zookeeper/conf/zoo.cfg <<EOF
tickTime=2000
dataDir=/data
clientPort=2181
initLimit=5
syncLimit=2
EOF

docker run -d \
  --name zookeeper \
  -p 2181:2181 \
  -v /root/zookeeper/data:/data \
  -v /root/zookeeper/datalog:/datalog \
  -v /root/zookeeper/conf/zoo.cfg:/conf/zoo.cfg \
  --restart=always \
  zookeeper:3.8
```

## jenkins

```bash
mkdir -p ~/jenkins_home

docker pull jenkins/jenkins:jdk17

docker run -d \
--name jenkins \
-p 28080:8080 \
-p 50000:50000 \
-v /etc/docker/certs.d:/etc/docker/certs.d:ro \
-v /etc/hosts:/etc/hosts:ro \
-v ~/jenkins_home:/var/jenkins_home \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /usr/bin/docker:/usr/bin/docker \
--group-add $(getent group docker | cut -d: -f3) \
--restart=always \
jenkins/jenkins:jdk17
```

内部需要用到 docker：

```bash
-v /var/run/docker.sock:/var/run/docker.sock \
-v /usr/bin/docker:/usr/bin/docker \
--group-add $(getent group docker | cut -d: -f3)
```

域名推送需要 nginx：

```bash
-v /etc/docker/certs.d:/etc/docker/certs.d:ro \
-v /etc/hosts:/etc/hosts:ro
```

首次进入密码：

```text
~/jenkins_home/secrets/initialAdminPassword
```

## nexus3

```bash
mkdir -p ~/nexus-data

sudo chown -R 200:200 ~/nexus-data

docker pull sonatype/nexus3

docker run -d \
--name nexus3 \
-p 28081:8081 \
-p 28082:8082 \
-p 28083:8083 \
-v ~/nexus-data:/nexus-data \
--restart=always \
sonatype/nexus3
```

开几个端口后面配置使用，如 `28082` 做 docker 仓库端口。

## minio

```bash
mkdir -p /data/minio

docker run -d \
--name minio \
-p 9100:9000 \
-p 9101:9001 \
-e "MINIO_ROOT_USER=admin" \
-e "MINIO_ROOT_PASSWORD=CHANGE_ME" \
-v /data/minio:/data \
--restart=always \
quay.io/minio/minio server /data --console-address ":9001"
```


