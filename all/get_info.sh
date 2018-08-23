#!/bin/bash
# 获得执行时间
allhosts_cnf="/tmp/all/allhosts.cnf"
masterinfo_list=($(cat ${allhosts_cnf}| awk -F "=" '/^master_host/{print $2}'))
allhosts="$(cat ${allhosts_cnf}| awk -F "=" '/^allhosts/{print $2}')"
date_time=$(date +%Y%m%d%H%M%S)
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
#创建临时目录
write_osinfo(){
    log_head [write_osinfo] [start]

        mkdir /tmp/${host_ip}
        #0S信息
        uname -a  &>> /tmp/${host_ip}/uname
        #主机名
        hostname &>> /tmp/${host_ip}/hostname
        #网卡信息
        ifconfig -a &>> /tmp/${host_ip}/ifconfig
        #路由表信息
        route -n   &>> /tmp/${host_ip}/route
        #CPU信息
        cat /proc/cpuinfo &>>  /tmp/${host_ip}/cpuinfo
        #物理内存和交换空间信息
        cat /proc/meminfo &>> /tmp/${host_ip}/meminfo 
        #硬盘信息
        fdisk -l  &>>  /tmp/${host_ip}/disk
        #文件系统信息
        df -T &>> /tmp/${host_ip}/filesystem
        #进程信息
        ps -elf | grep "mysqld" |grep -v "grep" &>> /tmp

    log_head [write_osinfo] [stop]
}
#健康检查
get_health(){
        log_head [get_health] [start]
        # 查看CPU总核数
            cpu_cores=$(cat /proc/cpuinfo | grep "^processor" | wc -l)
        # 获取物理CPU个数
            cpu_phy=$(cat /proc/cpuinfo | grep "^physical id" | sort| uniq | wc -l)
        # 获取每个CPU的核数
            cpu_core=$(cat /proc/cpuinfo | grep "^cpu cores" | uniq | awk '{print $NF}')
        # 判断是否等于物理CPU*每个CPU的核数
            if (( cpu_cores==cpu_phy*cpu_core ))
            then
                cpu=OK
            else
                cpu=Warning
            fi
            #查看内存是否使用交换空间
            mem=$(free | grep "^Swap" | awk '{print $(NF-1)}')
            if (( $mem>0 ))
            then
                mem=Warning 
            else
                mem=OK 
            fi

        #查看是否过度使用空间
            for i in $(df -PT | grep "^/dev" |egrep -v "sr." |awk '{print $NF}')
            do
                use_pct=$(df -PT | grep "^/dev" |grep "${i}$"|awk '{print $(NF-1)}'|tr -d "%")
                if (( use_pct>=20 ))
                then
                    space_info="${space_info} $i 空间不足80%"
                fi
            done
            if [[ -n ${space_info} ]]
            then
                space_info="异常,${space_info}"
            else
                space_info="正常"
            fi
        #查看文件系统是否读写正常
        #使用 [[ ]] 和 $()来判断字符串
            for i in $(df -PT | grep "^/dev" |egrep -v "sr." |awk '{print $NF}')
            do
                flag=$(mount | grep "$i" |egrep -v "sr."| grep "(ro")
                if  [[ -n ${flag} ]]
                then
                    echo ${flag}
                    fs_info="${fs_info} $i 只读"
                fi
            done

            if [[ -n ${fs_info} ]]
            then
                fs_info="异常,${fs_info}"
            else
                fs_info="正常"
            fi

        #查看mysql服务是否存在,不存在报异常
            if ps -elf | grep mysqld | grep -v "grep"
            then
                my_service="正常"
            else
                my_service="服务未启动"
            fi
    log_head [get_health] [start]
}
#创建报告
write_csv(){
    log_head [write_csv] [start]
        echo -e "基本信息"
        echo -e "主机名:,$(hostname)" 
        echo -e "IP地址:,$(ifconfig -a | grep "inet addr" |tr -s " "|cut -d : -f 2 |cut -d " " -f 1 | grep -v "127.0.0.1")"
        echo -e "默认网关:,$(route -n | grep "^0.0.0.0"|awk '{print $2}')"
        echo -e "内核版本:,$( uname -a |cut -d " " -f 3)"
        echo -e "CPU:,$(cat /proc/cpuinfo  | awk -F :  '/model name/{print $2}'|tr -d " "|tr '\n' ',')"
        echo -e "内存:,$(free  -h | grep '^Mem' |tr -s " " | cut -d " "  -f 2)"
        echo -e "\n"
        echo -e "健康检查:"
        echo -e "CPU检查:,,${cpu}"
        echo -e "内存检查:,,${mem}"
        echo -e "硬盘空间:,,${space_info}"
        echo -e "文件系统读写检查:,,${fs_info}"
        echo -e "进程检查:,,${my_service}"
    log_head [wwrite_csv] [stop]
}
#打包拷贝
info_copy(){
    log_head [info_copy] [start]
    echo "${masterinfo_list[0]}"
    echo "${host_ip}"
    #判断时候记得空格,否则判断失误
    if [[ ${masterinfo_list[0]} != ${host_ip} ]]
    then
        expect -c "
        #不加/,加了以后导致不将整个ip文件夹复制到allhosts中,而是单独复制文件
        spawn scp -r /tmp/${host_ip} ${masterinfo_list[1]}@${masterinfo_list[0]}:${allhosts}
        expect {
            \"*(yes/no)?\" {send \"yes\r\" ; exp_continue}
            \"*password:\" {send \"${masterinfo_list[2]}\r\" ; exp_continue}
        } 
    " 
    del_info &>>  /tmp/${host_ip}.log
    else
        mkdir ${allhosts}
        cp -rf /tmp/${host_ip} /allhosts/
        rm -rf /tmp/${host_ip}
    fi
       
    log_head [info_copy] [stop]
}
del_info(){
    rm -rf /tmp/${host_ip}
    rm -rf /tmp/all
}
main(){
    write_osinfo   &>>/tmp/${host_ip}.log
    get_health &>>/tmp/${host_ip}.log
    write_csv &> /tmp/${host_ip}/$(hostname)_$(date +%Y%m%d%H%M%S)_HealthReport.csv
    info_copy &>> /tmp/${host_ip}.log

}
main












