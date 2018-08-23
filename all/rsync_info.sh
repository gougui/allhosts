#!/bin/bash
#将脚本分发到每台主机上
while read ip user passwd
do
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
    " &>>/tmp/${ip}.log
done < ./slave_hosts
#执行本机
bash /tmp/all/get_info.sh
#