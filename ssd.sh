#!/bin/bash
# 自动扩容分区
# Author: admin@ym68.cc
# Date: 2022-10-21
# Version: 0.0.2

Echo_Failed_Code(){
    echo -e "[$(date "+%Y-%m-%d %H:%M:%S")] \033[31m${@}\033[0m"
    exit 3
}

Echo_Date_Out(){
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $@"
}
# 检查用户名89f2135ce3f3aa546a844a39816f9f6e8c7ae0b8c25c6d69c2b0b600aaa636
User_Login_Info=`whoami`
if [ ! "${User_Login_Info}" = 'root' ];then
    Echo_Date_Out "当前用户为 ${User_Login_Info} 非 root 用户!"
    exit 2
fi

# 设备名称
Default_Disk_Name='/dev/vda'
# 设备分区号
Default_Partition_Number='3'

if [ -b "${Default_Disk_Name}${Default_Partition_Number}" ];then
    Echo_Failed_Code "设备分区 ${Default_Disk_Name}${Default_Partition_Number} 存在，如非脚本执行中断，请修改设备分区号后重新执行!"
elif [ ! -b "${Default_Disk_Name}" ];then
    Echo_Failed_Code "设备 ${Default_Disk_Name} 不存在，请检查磁盘设备!"
fi
Echo_Date_Out "刷新 ${Default_Disk_Name} 磁盘分区表"
partprobe "${Default_Disk_Name}"|| Echo_Failed_Code "刷新磁盘分区表失败"
Echo_Date_Out "开始 ${Default_Disk_Name} 分区"
fdisk "${Default_Disk_Name}" << EOF
n
p
${Default_Partition_Number}


t

8e
p
w
EOF

Echo_Date_Out "刷新 ${Default_Disk_Name} 磁盘分区表"
partprobe "${Default_Disk_Name}"|| Echo_Failed_Code "刷新磁盘分区表失败"
sleep 1
if [ ! -b "${Default_Disk_Name}${Default_Partition_Number}" ];then
    Echo_Failed_Code "设备 ${Default_Disk_Name} 分区 ${Default_Partition_Number} 失败!"
fi
Echo_Date_Out "创建 ${Default_Disk_Name}${Default_Partition_Number} 物理卷"
pvcreate "${Default_Disk_Name}${Default_Partition_Number}"|| Echo_Failed_Code "创建 ${Default_Disk_Name}${Default_Partition_Number} 物理卷失败"
Echo_Date_Out "查看物理卷"
pvs -o+pv_used
Echo_Date_Out "添加 ${Default_Disk_Name}${Default_Partition_Number} 至centos卷组"
vgextend centos "${Default_Disk_Name}${Default_Partition_Number}"|| Echo_Failed_Code "添加 ${Default_Disk_Name}${Default_Partition_Number} 至centos卷组失败"
Echo_Date_Out "查看卷组"
vgs
Echo_Date_Out "开始扩容剩余100%容量"
lvextend -l +100%FREE '/dev/mapper/centos-root'|| Echo_Failed_Code "扩容磁盘容量失败"
Echo_Date_Out "查看逻辑卷"
lvs --noheadings
Echo_Date_Out "刷新磁盘容量信息"
FileSystem_Type=`df -TP|awk '/[[:space:]]\/$/ {print $2}'`
if [ "${FileSystem_Type}" = 'ext4' ];then
    resize2fs '/dev/mapper/centos-root'|| Echo_Failed_Code "刷新磁盘容量 ${FileSystem_Type}  信息失败"
elif [ "${FileSystem_Type}" = 'xfs' ];then
    xfs_growfs '/dev/mapper/centos-root'|| Echo_Failed_Code "刷新磁盘容量 ${FileSystem_Type}  信息失败"
else
    Echo_Failed_Code "查询文件系统格式失败!"
fi
Echo_Date_Out "查看磁盘容量信息"
lsblk
Echo_Date_Out "查看系统盘容量"
df -h