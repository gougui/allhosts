#!/bin/bash
#将脚本分发到每台主机上
#执行本机
#为cat提供参数
allhosts_cnf="/tmp/all/allhosts.cnf"
#存放 各个主机信息的目录
allhosts="$(cat ${allhosts_cnf}| awk -F "=" '/^allhosts/{print $2}')"
#备份主机
backup_host_list=($(cat ${allhosts_cnf}| awk -F "=" '/^backup_host/{print $2}'))
#备份目录
backup_dir="$(cat ${allhosts_cnf}| awk -F "=" '/^backup_dir/{print $2}')"


# 获取主机IP
host_ip=$(ifconfig -a | grep "inet addr" |tr -s " "|cut -d : -f 2 |cut -d " " -f 1 | grep -v "127.0.0.1"|head -1)
#日志函数 log_head [write_osinfo] [start] 第二个带参数
log_head(){
    date_now="Time: `date +%Y%m%d%H%M%S` Function:  \033[32m $1 \033[0m"
    echo -e "\033[46;31m ***log*** \033[0m" &>>/tmp/${host_ip}.log
    if [[ -n $2 ]]
    then
        echo -e "${date_now}  Action: \033[32m $2 \033[0m" &>>/tmp/${host_ip}.log
    else
        echo -e  ${date_now}  &>>/tmp/${host_ip}.log
    fi
}
#退出函数
exit_func(){
    log_head "$1" "\033[42;31m \033[5m [ERROR]  \033[0m \033[0m \033[31m [异常终止退出!!] \033[0m " &>>/tmp/${host_ip}.log
    exit
}
bash /tmp/all/get_info.sh
while read ip user passwd
do
    log_head [copy_all_scripts] [start]
     expect -c "
        spawn scp -r /tmp/all ${user}@${ip}:/tmp/
        expect {
            \"*(yes/no)?\" {send \"yes\r\" ; exp_continue}
            \"*password:\" {send \"${passwd}\r\" ; exp_continue}
        } 
        spawn ssh ${user}@${ip} . /tmp/all/get_info.sh
        expect {
            \"*password:\" {send \"${passwd}\r\" ; exp_continue}
        }    
    " &>>/tmp/${host_ip}.log
    log_head [copy_all_scripts] [stop]
done < ./slave_hosts
#使用rsync同步.
#需要手动创建备份文件夹,使用spawn
rsync_allhosts(){

   expect -c "
    spawn   ssh ${backup_host_list[0]}
     expect {
            \"*(yes/no)?\" {send \"yes\r\" ; exp_continue}
            \"*password:\" {send \"${backup_host_list[2]}\r\" ; exp_continue}
        }; 
        expect \"*]#\" { send \"mkdir -p ${backup_dir}\r\"};            
        expect \"*]#\" { send \"exit\r\"};
        expect eof;
    "

    expect -c "
    spawn   rsync -avz ${allhosts} ${backup_host_list[1]}@${backup_host_list[0]}:${backup_dir}
     expect {
            \"*(yes/no)?\" {send \"yes\r\" ; exp_continue}
            \"*password:\" {send \"${backup_host_list[2]}\r\" ; exp_continue}
        } 
    "
}

rsync_allhosts &>>/tmp/${host_ip}.log
#