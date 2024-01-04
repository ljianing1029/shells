#!/bin/bash
#

MONGODB_VERSOIN=ubuntu1804-5.0.3

MONGODB_FILE=mongodb-linux-x86_64-${MONGODB_VERSOIN}.tgz
#MONGODB_FILE=mongodb-linux-x86_64-ubuntu1804-5.0.3.tgz
URL=https://fastdl.mongodb.org/linux/$MONGODB_FILE
MONGODB_DIR=/mongodb
INSTALL_DIR=/usr/local
PORT=27017
MY_IP=`hostname -I|awk '{print $1}'`

. /etc/os-release

color () {
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
    SETCOLOR_NORMAL="echo -en \E[0m"
    echo -n "$1" && $MOVE_TO_COL
    echo -n "["
    if [ $2 = "success" -o $2 = "0" ] ;then
        ${SETCOLOR_SUCCESS}
        echo -n $"  OK  "    
    elif [ $2 = "failure" -o $2 = "1"  ] ;then 
        ${SETCOLOR_FAILURE}
        echo -n $"FAILED"
    else
        ${SETCOLOR_WARNING}
        echo -n $"WARNING"
    fi
    ${SETCOLOR_NORMAL}
    echo -n "]"
    echo 
}


system_prepare () {
    [ -e $MONGODB_DIR -o -e $INSTALL_DIR/mongodb ] && { color  "MongoDB 数据库已安装!" 1;exit; }
    if  [ $ID = "centos" -o $ID = "rocky" ];then
        rpm -q curl  &> /dev/null || yum install -y -q curl
    elif [ $ID = "ubuntu" ];then
        dpkg -l curl &> /dev/null || apt -y install curl
    else
        color  '不支持当前操作系统!' 1
        exit
    fi
    if [ -e /etc/rc.local ];then
        echo "echo never > /sys/kernel/mm/transparent hugepage/enabled" >> /etc/rc.local
    else
        cat > /etc/rc.local <<EOF
#!/bin/bash
echo never > /sys/kernel/mm/transparent hugepage/enabled
EOF
    fi
    chmod +x /etc/rc.local   
}

mongodb_file_prepare () {
    if [ ! -e $MONGODB_FILE ];then
        curl -O  $URL || { color  "MongoDB 数据库文件下载失败" 1; exit; } 
    fi
}

install_mongodb () {
    id mongod &> /dev/null || useradd -m -s /bin/bash mongod
    tar xf $MONGODB_FILE -C $INSTALL_DIR
    ln -s $INSTALL_DIR/mongodb-linux-x86_64-${MONGODB_VERSOIN} $INSTALL_DIR/mongodb
    #mongod --dbpath $db_dir --bind_ip_all --port $PORT --logpath $db_dir/mongod.log --fork
}

config_mongodb(){
    echo PATH=$INSTALL_DIR/mongodb/bin/:'$PATH' > /etc/profile.d/mongodb.sh
    . /etc/profile.d/mongodb.sh
    mkdir -p $MONGODB_DIR/{conf,data,log}
    cat > $MONGODB_DIR/conf/mongo.conf <<EOF
systemLog:
  destination: file
  path: "$MONGODB_DIR/log/mongodb.log"
  logAppend: true

storage:
  dbPath: "$MONGODB_DIR/data/"
  journal:
    enabled: true
 
processManagement:
  fork: true

net:
  port: 27017
  bindIp: 0.0.0.0
EOF
    chown -R  mongod.mongod $MONGODB_DIR/
    cat > /lib/systemd/system/mongod.service <<EOF
[Unit]
Description=mongodb
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
User=mongod
Group=mongod
ExecStart=$INSTALL_DIR/mongodb/bin/mongod --config $MONGODB_DIR/conf/mongo.conf
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=$INSTALL_DIR/bin/mongod --config $MONGODB/conf/mongo.conf --shutdown
PrivateTmp=true
# file size
LimitFSIZE=infinity
# cpu time
LimitCPU=infinity
# virtual memory size
LimitAS=infinity
# open files
LimitNOFILE=64000
# processes/threads
LimitNPROC=64000
# locked memory
LimitMEMLOCK=infinity
# total threads (user+kernel)
TasksMax=infinity
TasksAccounting=false
# Recommended limits for mongod as specified in
# https://docs.mongodb.com/manual/reference/ulimit/#recommended-ulimit-settings

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now  mongod &>/dev/null
}

start_mongodb() { 
    systemctl is-active mongod.service &>/dev/null
    if [ $?  -eq 0 ];then  
        echo 
        color "MongoDB 安装完成!" 0
    else
        color "MongoDB 安装失败!" 1
        exit
    fi 
}

system_prepare 
mongodb_file_prepare
install_mongodb
config_mongodb
start_mongodb
