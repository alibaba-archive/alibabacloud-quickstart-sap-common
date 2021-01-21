#!/bin/bash
######################################################################
#functions.sh
#The script is the core component of the SAP automated installation tool, used to initialize the environment,configure cloud infrastructure,define log function,download and extract software,etc.
#Author: Alibaba Cloud, SAP Product & Solution Team
######################################################################
#Tool versions
QUICKSTART_SAP_COMMON_VERSION='1.0.2'


######################################################################
# Help functions
######################################################################
# Define help function
# help
function help(){
    cat <<EOF
help: $1 [options]
    -f, --config-file       Parameters template path
    -s, --step              Installation step
    -h, --help              Show this help message and exit
    -v, --version           Show version and exit
For example: $0 -f parameter.cfg
EOF
    exit 0
}

# Define show_version function
# show_version 
function show_version(){
    echo "Alibaba Cloud quickstart-sap-common Version: ${QUICKSTART_SAP_COMMON_VERSION}"
    echo "Alibaba Cloud quickstart-${QUICKSTART_SAP_MOUDLE} Version: ${QUICKSTART_SAP_MOUDLE_VERSION}"
    exit 0
}


######################################################################
# Log functions
######################################################################
# Define log function
# log message [level=3]
function log(){
    local msg;local level
    msg=$1
    level=${2:-'3'}
    datetime=`date +'%F %H:%M:%S'`
    logformat="${datetime} ${BASH_SOURCE[1]}[`caller 1 | awk '{print $1}'`]: ${msg}"
    case $level in
        3)
            echo -e "\033[32m[INFO] ${logformat}\033[0m" ;;
        2)
            echo -e "\033[33m[WARNING] ${logformat}\033[0m" ;;
        1)
            echo -e "[ERROR] ${logformat}" >&2 ;;
    esac
}

function error_log(){
    log "$*" 1
}

function warning_log(){
    log "$*" 2
}

function info_log(){
    log "$*" 3
}


######################################################################
# Exit and cleanup functions
######################################################################
# Define EXIT function
# EXIT[level: 0,1]
function EXIT(){
    clean_level="${SAP_CLEAN_LEVEL-$1}"
    clean_up "${clean_level}"

    if [[ $1 == "0" ]];then
        info_log "Install successful" 
    else
        error_log "Install failed" 
        echo -e "\015"
        kill -s TERM $TOP_PID
    fi
    echo -e "\015"
    exit 0
}

# Define clean_up function
function clean_up() {
    level=${1:-1}
    info_log "Start to cleanup action"
    case $level in 
        0) 
            rm -rf $QUICKSTART_SAP_DOWNLOAD_DIR/ && log "Installation finished and cleanup $QUICKSTART_SAP_DOWNLOAD_DIR/"   
            ;;
        1)  
            info_log "Don't need to cleanup"
            ;;
        *)  ;;
    esac
    rm -rf ${QUICKSTART_SAP_INSTALL_FIFO} ${QUICKSTART_SAP_ERROR_FIFO}
}


######################################################################
# Print functions
######################################################################
# Define print_params function
# print_params
function print_params(){
    echo "####################################"
    echo "Parameters:"
    for param in ${PARAMS[@]}
    do
        eval value="\$$param"
        echo "    $param: $value"
    done
    echo "####################################"
}


######################################################################
# Initialize enviroment functions
######################################################################
# Define init_env function
# init_env
function init_env(){
    export QUICKSTART_SAP_REGION=$(curl "http://100.100.100.200/2016-01-01/meta-data/region-id" -s)
    export QUICKSTART_SAP_OS_RELEASE="$(lsb_release -a | grep 'Release' | awk  '{print $2}')"
    export QUICKSTART_SAP_OS_DISTRIBUTOR="$(lsb_release -a | grep 'Distributor ID' | awk  '{print $3}')"
    export QUICKSTART_SAP_DOWNLOAD_DIR="/usr/sap/install/download"
    export QUICKSTART_SAP_EXTRACTION_DIR="/usr/sap/install"
    export QUICKSTART_SAP_LOG_DIR="/var/log/alibabacloud-quickstart-sap"
    export QUICKSTART_SAP_INSTALL_LOG="${QUICKSTART_SAP_LOG_DIR}/Install.log"
    export QUICKSTART_SAP_ERROR_LOG="${QUICKSTART_SAP_LOG_DIR}/Error.log"
    export QUICKSTART_SAP_INSTALL_FIFO="${QUICKSTART_SAP_LOG_DIR}/install.fifo"
    export QUICKSTART_SAP_ERROR_FIFO="${QUICKSTART_SAP_LOG_DIR}/error.fifo"
    export QUICKSTART_SAP_MARK="${QUICKSTART_SAP_LOG_DIR}/Mark.log"
    export QUICKSTART_SAP_VERSION="V1"
    export QUICKSTART_SAP_CLEANUP_LEVEL=""
    export ETC_FSTAB_PATH="/etc/fstab"
    export CONFIG_ETH0_PATH="/etc/sysconfig/network/ifcfg-eth0"
    export CONFIG_OSSUTIL_PATH="/root/.ossutilconfig"
    export LVM_SUPPRESS_FD_WARNINGS=1
    export LC_ALL=C
    export TOP_PID=$$
    trap 'exit 1' TERM

    RE_IP="^((192\\.168|172\\.([1][6-9]|[2]\\d|3[01]))(\\.([2][0-4]\\d|[2][5][0-5]|[01]?\\d?\\d)){2}|(\\D)*10(\\.([2][0-4]\\d|[2][5][0-5]|[01]?\\d?\\d)){3})$"
    RE_DISK="(^[2-9]\\d{1}$)|(^[1-9]\\d{2}$)|(^[1-9]\\d{3}$)|(^[1-2]\\d{4}$)|(^3[0-2][0-7][0-6][0-8]$)"
    RE_INSTANCE_NUMBER="^([0-8][0-9]|9[0-6])$"
    RE_SID="^([A-Z]{1}[0-9A-Z]{2})$"
    RE_HOSTNAME="^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-])*([a-zA-Z0-9])$"
    RE_PASSWORD="^(?=.*[0-9].*)(?=.*[A-Z].*)(?=.*[a-z].*)[a-zA-Z][0-9a-zA-Z_@#$]{7,}$"

    mkdir -p "${QUICKSTART_SAP_LOG_DIR}"
    $(ls "${QUICKSTART_SAP_LOG_DIR}" | grep -q "${QUICKSTART_SAP_INSTALL_FIFO##*/}") || mkfifo "${QUICKSTART_SAP_INSTALL_FIFO}"
    $(ls "${QUICKSTART_SAP_LOG_DIR}" | grep -q "${QUICKSTART_SAP_ERROR_FIFO##*/}") || mkfifo "${QUICKSTART_SAP_ERROR_FIFO}"

    cat ${QUICKSTART_SAP_INSTALL_FIFO} | tee -a ${QUICKSTART_SAP_INSTALL_LOG} &
    exec 1>>${QUICKSTART_SAP_INSTALL_FIFO}
    cat ${QUICKSTART_SAP_ERROR_FIFO} | tee -a ${QUICKSTART_SAP_ERROR_LOG} &
    exec 2>${QUICKSTART_SAP_ERROR_FIFO}

    ECSHostname="$(hostname)"
    ECSIpAddress=$(curl "http://100.100.100.200/latest/meta-data/private-ipv4" 2>/dev/null)
    sed -i "/127.0.0.1.*${ECSHostname}/d" /etc/hosts

    touch $QUICKSTART_SAP_MARK
}

# Define check_repo function
# check_repo
function check_repo(){
    zypper -qn remove unrar 2>/dev/null
    zypper -qn install unrar 2>/dev/null
}

# Define init_repo function
# init_repo
function init_repo(){
    check_repo
    if [[ $? -ne 0 ]]
    then
        SUSEConnect --cleanup
        $(systemctl list-units --all  | grep -q guestregister.service) && systemctl start guestregister.service
        zypper ref
    else
        return 0
    fi

    check_repo
    if [[ $? -ne 0 ]]
    then
        error_log "zypper repo is unavailable"
        EXIT 1
    fi
}

# Define ntp_config function
# ntp_config
function ntp_config(){
    service ntpd stop
    ntpdate ntp.cloud.aliyuncs.com
    service ntpd start
}

#Define install_package package
function install_package(){
    for package in $@
    do 
        if ! rpm -q ${package};then
            info_log "Start to install ${package}."
            zypper --non-interactive --quiet --gpg-auto-import-keys install ${package} || { error_log "${package} don't install,please check";return 1; }
        fi
    done
}

# Define sync_time function
# sync_time
function sync_time(){
    date_diff=$(($(date +%s) - $(date -d "$(curl -H 'Cache-Control: no-cache' -sD - http://100.100.100.200 |grep '^Date:' |cut -d' ' -f3-6) UTC" +%s)))
    if [[ ${date_diff#-} -gt 60 ]]; then
        date -u --set="$(curl -H 'Cache-Control: no-cache' -sD - http://100.100.100.200 |grep '^Date:' |cut -d' ' -f3-6)"
    fi
}

# Define update_aliyun_assist function
# update_aliyun_assist
function update_aliyun_assist(){
    $(ps -ef | grep -v grep| grep -q qemu-ga) && systemctl stop qemu-ga@virtio\\x2dports-org.qemu.guest_agent.0.service && systemctl disable qemu-ga@virtio\\x2dports-org.qemu.guest_agent.0.service
    rpm -ivh --force "https://aliyun-client-assist-${QUICKSTART_SAP_REGION}.oss-${QUICKSTART_SAP_REGION}-internal.aliyuncs.com/linux/aliyun_assist_latest.rpm"
}

# Define install_ossutil function
# install_ossutil
function install_ossutil(){
    if ossutil64 --version >/dev/null  2>&1
    then
        return 0
    fi
    info_log "Start to install ossutil64"
    wget -q http://gosspublic.alicdn.com/ossutil/1.6.10/ossutil64 -O /usr/bin/ossutil64
    chmod 755 /usr/bin/ossutil64

    if ! ossutil64 --version >/dev/null  2>&1
    then
        error_log "Install ossutil failed"
        EXIT
    fi
}

# Define config_ossutil function
# config_ossutil
function config_ossutil(){
    endpoint="oss-${QUICKSTART_SAP_REGION}-internal.aliyuncs.com"
    sap_ram_role=`curl http://100.100.100.200/latest/meta-data/ram/security-credentials/ -s`
    cat <<EOF > ${CONFIG_OSSUTIL_PATH}
[Credentials]
        language = EN
        endpoint = ${endpoint}
[AkService]
        ecsAk=http://100.100.100.200/latest/meta-data/Ram/security-credentials/${sap_ram_role}
EOF

    sync_time

    ossutil64 ls -c "${CONFIG_OSSUTIL_PATH}" > /dev/null
    if [[ $? -ne 0 ]]
    then
        error_log "Configure ossutil failed"
        EXIT
    fi
}

# Define init_software function
# init_software
function init_software(){
    info_log "Start to check software."
    init_repo
    install_package unrar >/dev/null
    update_aliyun_assist
    install_package lvm2 expect libltdl7 telnet tcsh autofs
    install_ossutil
    config_ossutil
}

# Define check_para function
# check_para param_name re 
function check_para(){ 
    eval value="\$$1"
    $(echo "$value" | grep -qP "$2") || { error_log "$1($value) does not meet the policy requirements"; EXIT 1; }
}

#Define os_suse_pre function
#os_suse_pre
function os_suse_pre(){
    case "${QUICKSTART_SAP_OS_RELEASE}" in
        12*)
            ntp_config
            ;;
        15*)
            echo 15 >/dev/null
            ;;
        *)
            error_log "Operating system version(Suse ${QUICKSTART_SAP_OS_RELEASE}) is not supported"
            EXIT 1
            ;;
    esac
    init_software
}

#Define os_pre function
#os_pre
function os_pre(){
    case "${QUICKSTART_SAP_OS_DISTRIBUTOR}" in
        "SUSE")
            os_suse_pre
            ;;
        *)
            error_log "Operating system(${QUICKSTART_SAP_OS_DISTRIBUTOR}) is not supported"
            EXIT
            ;;
    esac
}


######################################################################
# Download and extract software functions 
######################################################################
# Define download function
# download url download_path 
function download(){
    url="$1"
    file_name="$2"
    download_path="${QUICKSTART_SAP_DOWNLOAD_DIR}"
    [[ ! -d "$download_path" ]] && { error_log "'${download_path}' does not exist"; return 1; }

    info_log "Start to download ${url}"
    if [[ "$url" =~ ^oss.* ]];then
        if [[ ! "$url" =~ .*\.(ZIP|zip)$ ]] && [[ ! "$url" =~ .*/$ ]];then
            url="$url/"
        fi
        sync_time
        ossutil64 cp ${url} ${download_path} -r -c "${CONFIG_OSSUTIL_PATH}" || { error_log "Download failed(${url})"; return 1; }
    elif [[ "$url" =~ ^http.* ]];then
        [[ -z "$file_name" ]] && { error_log "'file_name' must be specified"; return 1; }
        wget -nv "$url" -O "$download_path/$file_name" -t 2 -c || { error_log "Download failed(${url})"; return 1; }
    else
        error_log "Url($url) is not supported"
        return 1
    fi
}

# Define download_medias function
# download_medias url
function download_medias(){
    url="$1"
    download_path="${QUICKSTART_SAP_DOWNLOAD_DIR}"
    [[ ! -d "$download_path" ]] && { error_log "'${download_path}' does not exist"; return 1; }

    info_log "Start to download ${url}"
    if [[ "$url" =~ ^oss.* ]];then
        if [[ ! "$url" =~ .*\.(ZIP|zip)$ ]] && [[ ! "$url" =~ .*/$ ]];then
            url="$url/"
        fi
        sync_time
        ossutil64 cp ${url} ${download_path} -r -c "${CONFIG_OSSUTIL_PATH}" || { error_log "Download failed(${url})"; return 1; }
    elif [[ "$url" =~ ^http.* ]];then
        wget -nv "${url}" -O "$download_path/urls.csv" -t 2 -c || { error_log "Download failed(${url})"; return 1; }
        if [[ -s "$download_path/urls.csv" ]]
        then
            if [[ `head -1 "$download_path/urls.csv"` == 'object,url' ]]
            then

                for u in `awk -F ',' '{if (NR>1){print $2}}' "$download_path/urls.csv"`
                do
                    info_log "Downloading file(${u})"
                    wget -nv "$u" -P "$download_path" -t 2 -c || { error_log "Download failed(${u})"; return 1; }
                done
            else
                error_log "File($url) is not supported"
                return 1
            fi
        fi
    else
        error_log "Url($url) is not supported"
        return 1
    fi
}

#Define sar_extraction function
#sar_extraction file_path extraction_path [manifest]
function sar_extraction(){
    file_path="$1"
    extraction_path="$2"
    sap_car_path="${QUICKSTART_SAP_DOWNLOAD_DIR}/SAPCAR.EXE"
    sap_car_url="http://sap-automation-${QUICKSTART_SAP_REGION}.oss-${QUICKSTART_SAP_REGION}.aliyuncs.com/alibabacloud-quickstart/packages/SAPCAR_1311-80000935.EXE"

    if ! [[ -s "${sap_car_path}" ]]
    then
        download "${sap_car_url}" "SAPCAR.EXE"
        chmod +x "${sap_car_path}"
    fi
    cd "${extraction_path}"
    info_log "Start to extract ${file_path}"
    if [[ -z "$3" ]]
    then
        "${sap_car_path}" -xf "${file_path}" > /dev/null
    else
        "${sap_car_path}" -xf "${file_path}" -manifest SIGNATURE.SMF > /dev/null
    fi
}

#Define extraction function
#extraction file_path
function extraction(){
    local file_path="$1"
    local extraction_path=${QUICKSTART_SAP_EXTRACTION_DIR:-'.'}
    [[ ! -d "$extraction_path" ]] && { error_log "'${extraction_path}' does not exist"; return 1; }
    info_log "Start to extract $file_path"
    case $file_path in
        *.tar.bz2)      tar xjf $file_path  -C  $extraction_path    ;;
        *.tar.gz)       tar xzf $file_path  -C  $extraction_path    ;;
        *.tar)          tar xf $file_path   -C  $extraction_path    ;;
        *.tbz2)         tar xjf $file_path  -C  $extraction_path    ;;
        *.tgz)          tar xzf $file_path  -C  $extraction_path    ;;
        *.zip)          unzip  -o $file_path  -d $extraction_path   ;;
        *.ZIP)          unzip  -o $file_path  -d $extraction_path   ;;
        *.exe)          unrar  x $file_path  $extraction_path/      ;;
        *) error_log "$file_path：There is no supported compress type" && exit 1;;
    esac
    info_log "Finished $file_path extraction "
}

# Define auto_extraction function
# auto_extraction dir_path
function auto_extraction(){
    path=$1
    if [[ -f "$path" ]];then
        extraction "$path" 1>/dev/null || return 1
    elif [[ -d "$path" ]];then
        for file in `ls $path|grep -P "(\.exe)|(\.ZIP)|(\.zip)"`;do 
            extraction "$path/$file" 1>/dev/null || return 1
        done
    else
        error_log "Path($path) is invalid file"
        return 1
    fi
}

# Define check_export_1909 function
# check_export_1909 basket_path
function check_export_1909(){
    local basket_path="${1}"
    if [[ ! $(ls ${basket_path} | grep -E "^S4CORE[0-9]+_INST_EXPORT_[0-9]+\.zip$" |wc -l) -eq 25 ]];then 
        error_log "File (Export) not found in (${basket_path})"
        return 1
    fi
}

# Define check_export_1809 function
# check_export_1809 basket_path
function check_export_1809(){
    local basket_path="${1}"
    if [[ ! $(ls ${basket_path} | grep -E "^S4CORE[0-9]+_INST_EXPORT_[0-9]+\.zip$" |wc -l) -eq 20 ]];then 
        error_log "File (Export) not found in (${basket_path})"
        return 1
    fi
}

# Define check_app_media function
# check_app_media basket_path
function check_app_media(){
    local basket_path="${1}"
    if ! ls ${basket_path} | grep -qE "^IMDB_CLIENT[0-9_-]+\.SAR$";then 
        error_log "File (HANA Client: IMDB_CLIENT) not found in (${basket_path})"
        return 1
    fi
    if ! ls ${basket_path} | grep -qE "^igsexe[0-9_-]+.sar$";then 
        error_log "File (Kernel: igsexe...) not found in (${basket_path})"
        return 1
    fi
    if ! ls ${basket_path} | grep -qE "^igshelper[0-9_-]+.sar$";then 
        error_log "File (Kernel: igshelper...) not found in (${basket_path})"
        return 1
    fi
    if ! ls ${basket_path} | grep -qE "^SAPEXE[0-9_-]+.SAR$";then 
        error_log "File (Kernel: SAPEXE...) not found in (${basket_path})"
        return 1
    fi
    if ! ls ${basket_path} | grep -qE "^SAPEXEDB[0-9_-]+.SAR$";then 
        error_log "File (Kernel: SAPEXEDB...) not found in (${basket_path})"
        return 1
    fi
    if ! ls ${basket_path} | grep -qE "^SAPHOSTAGENT[0-9_-]+.SAR$";then 
        error_log "File (Kernel: SAPHOSTAGENT...) not found in (${basket_path})"
        return 1
    fi
}

# Define check_media_1809 function
# check_media_1809 basket_path
function check_media_1809(){
    check_export_1809 "${1}" || return 1
    check_app_media "${1}" || return 1
}


######################################################################
# Configure cloud infrastructure functions
######################################################################
#Define DNS function
#DNS
function DNS(){
    for i in "100.100.2.138" "100.100.2.136"
    do 
        grep -q "nameserver $i" /etc/resolv.conf || sed -i '$a nameserver '"$i" /etc/resolv.conf
        grep -q "nameserver $i" /etc/resolv.conf || { echo "[ERROR] `date +'%F %H:%M:%S'` $0:${LINENO} Change DNS failed"  >&2 ; return 1; }
    done
}

#Define config_host function
#config_host 
function config_host(){
    data="$1"
    grep "${data}" -q /etc/hosts || { echo "${data}" >> /etc/hosts; info_log "Add host(${data})"; }
    grep "${data}" -q /etc/hosts || { error_log "added host(${data}) file failed" ; return 1; }
}

# Define check_disks function
# check_disks disk_id1 disk_id2 ...
function check_disks(){
    for disk_id in $@
    do
        $(lsblk| grep -q $disk_id) || { error_log "Disk ${disk_id} does not exist"; return 1; }
    done
}

#Define create_lv function
#create_lv size lv_name vg_name is_free striping
function create_lv(){
    size=" -L $1g "
    if [[ `vgs --units g|grep -w $3|awk -vsize="$1" '{match($7,/([0-9.]+)/,a);print(a[1] <= size)}'` -eq "1" ]]; then
        if [ "$4" = "free" ];then
            size=" -l 100%free "
        else
            error_log "DiskSize($2) is big than vg-free"
            return 1
        fi
    fi

    if [ -n "$5" ];then
        striping=" -i $5 -I 256 "
    else
        striping=" "
    fi
    expect <<EOF
    set timeout 1
    spawn lvcreate $size $striping -n $2 $3
    expect {
        "y/n" {
            send "n\n"
        }
        "created" {
            send "\n"
        }
    } 
    interact
EOF
    $(lvs | grep -q "$2") || { error_log "Create a logical volume($2) failed"; return 1; }
}

#Define mk_swap function
#mk_swap SwapDiskId
function mk_swap(){
    local swap_id=$1
    if swapon -s | grep -q "${swap_id}";then
        warning_log "Swap disk has created"
        return 0
    fi
    info_log "Now Start to create swap"
    mkswap  ${swap_id} && swapon  ${swap_id}
    if swapon -s | grep -q "${swap_id}";then
        $(grep -q ${swap_id} ${ETC_FSTAB_PATH}) || echo "${swap_id}        swap    swap    defaults        0 0" >> ${ETC_FSTAB_PATH}
        info_log "Create swap successful"
    else
        warning_log "Create swap failed"
    fi
}

# Define config_nas function
# config_nas NASDomain FileSystem
function config_nas(){
    nas_domain="$1"
    file_system="$2"
    grep "/- /etc/auto.nfs" /etc/auto.master > /dev/null 2>&1 || echo "/- /etc/auto.nfs" >> /etc/auto.master
    touch /etc/auto.nfs
    grep "${file_system} -rw,hard,intr,timeo=60,retrans=2   ${nas_domain}:/" /etc/auto.nfs || echo "${file_system} -rw,hard,intr,timeo=60,retrans=2   ${nas_domain}:/" >> /etc/auto.nfs
}

# Define check_filesystem function
# check_filesystem filesystem1 filesystem2 ...
function check_filesystem() {
    info_log "Now checking file systems status"
    for filesystem in $@
    do
        $(df -h | grep -q $filesystem) || { error_log "File system ${filesystem} does not exist"; return 1; }
    done
    info_log "Both HANA relevant file systems have been mounted successful"
}

# Define config_ssh function
# config_ssh ip user password
function config_ssh(){
    ip=${1}
    user=${2}
    password=${3}

    if [[ -z "${HOME}" ]]
    then
        HOME='/root'
    fi
    if [[ ! -f "${HOME}/.ssh/id_rsa" ]] || [[ ! -f "${HOME}/.ssh/id_rsa.pub" ]]
    then
        expect << EOF
            set timeout 10
            spawn ssh-keygen -t rsa
            expect {
                    "*verwrite" {send "y\r";exp_continue}
                    "*Enter*" {send "\r";exp_continue}
                    "*SHA256" {send "\r"}
                }
        interact
EOF
    fi

    expect << EOF
    set timeout 10
    spawn ssh-copy-id -i ${HOME}/.ssh/id_rsa.pub ${user}@${ip}
    expect {
            "*yes/no" { send "yes\r";exp_continue}
            "*assword:" { send "${password}\r";exp_continue}
            "*were added" { send "\r"}
            }
    interact
EOF
}

# Define ssh_setup function
# ssh_setup 'ip1 ip2 ip3...' user password
function ssh_setup(){
    ssh_ip=${1}
    ssh_user=${2}
    password=${3}
    for ip in ${ssh_ip}
    do
        config_ssh ${ip} ${ssh_user} ${password}
    done
}

#Define run_cmd function
#run_cmd command user
function run_cmd(){
    user=$2
    command=$1
    su - "${user}" -c "${command}" 2>/dev/null
}

#Define run_cmd_remote function
#run_cmd_remote ip command user
function run_cmd_remote(){
    command=$2
    ip=$1
    user=${3:-root}
    ssh "${user}@${ip}" "${command}"
}

# Define config_eni function
# config_eni ip network-card
function config_eni(){
    heart_ip=${1}
    network_card=${2}
    info_log "Start to configure ENI($heart_ip  $network_card)"
    HWaddr=$(ip addr show dev "${network_card}" | grep link/ether | awk '{print $2}')
    if [ -z "${HWaddr}" ];then
        error_log "Matching Mac address failed of network card device ${network_card}"
        return 1
    fi
    mask=`curl http://100.100.100.200/latest/meta-data/network/interfaces/macs/${HWaddr}/netmask 2>/dev/null`
    cat << EOF > /etc/sysconfig/network/ifcfg-${network_card}
DEVICE='${network_card}'
BOOTPROTO='static'
NETMASK='${mask}'
IPADDR='${heart_ip}'
HWADDR='${HWaddr}'
STARTMODE='auto'
EOF
    service network restart
    if ! $(ip addr show dev "${network_card}" | grep -q "${heart_ip}");then
        error_log "Configure network card ${network_card} failed"
        return 1
    fi
}

#Define SBD configuration function
#sbd_config QuorumDisk
function sbd_config(){
    info_log "Start to configure SBD" 
    quorum_disk=$1
    lsblk | grep "${quorum_disk}" || { error_log "Can't find shared block device:${quorum_disk}"; return 1; }
    quorum_disk="/dev/${quorum_disk}"
    expect << EOF
    set timeout 180
    spawn sbd -d "${quorum_disk}" create
    expect {
            "*initialized*" {send "\r";}
            timeout {exit 2 }
        }
    interact
EOF
    if [ $? -eq 2 ];then
        error_log "Configure SBD timeout"
        return 1
    fi
    sbd -d "${quorum_disk}" dump
    if [ $? -ne 0 ];then
        error_log "Create SBD failed"
        return 1
    fi
    grep -q "modprobe softdog" /etc/init.d/boot.local || echo "modprobe softdog" >> /etc/init.d/boot.local
    modprobe softdog
    lsmod | egrep "(wd|dog)" || { error_log "Conigure software watchdog failed" ; return 1; }
    sed -i "s|#SBD_DEVICE=.*|SBD_DEVICE=\"${quorum_disk}\"|g" /etc/sysconfig/sbd
    sed -i "s|SBD_DEVICE=.*|SBD_DEVICE=\"${quorum_disk}\"|g" /etc/sysconfig/sbd
    sed -i 's/SBD_STARTMODE=.*/SBD_STARTMODE=clean/g' /etc/sysconfig/sbd
    sed -i 's/SBD_OPTS=.*/SBD_OPTS="-W -P"/g' /etc/sysconfig/sbd
    /usr/share/sbd/sbd.sh start || warning_log "/usr/share/sbd/sbd.sh start failed"
    sbd -d "${quorum_disk}" list | grep -P "$(hostname)\s+clear" || { error_log "Configure SBD failed";return 1; }
    info_log "SBD configuration has been finished successful"
    return 0
}

#Define start_hawk function
#start_hawk [password]
function start_hawk(){
    if [[ -n "$1" ]]
    then
        ( echo -e  "$1\n$1" ) | passwd hacluster
    fi
    info_log "Start to restart Hawk2" 
    systemctl restart hawk.service || warning_log "Failed to start Hawk2"
}

#Define version_lt function
#version_lt version1 version2
function version_lt(){ test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }

#Define res_validation function
# res_validation res re_str
function res_validation(){
    res=$1
    re_str=$2
    for num in $(seq 1 20)
    do 
        $(crm_mon -1 | grep -qP "${re_str}") && return 0
        sleep 1m
    done
    warning_log "Resource ${res} validate failed"
    return 1
}


######################################################################
# Install SAP related software functions
######################################################################
#Define single_node_install package
function single_node_packages(){
    install_package uuidd saptune
    metrics_collector_install
}

#Define HA_install function
function HA_packages(){
    single_node_packages
    install_package sbd pacemaker corosync SAPHanaSR patterns-ha-ha_sles resource-agents
}

#Define post function
function post(){
    local solution=$1
    saptune solution apply ${solution}
    saptune daemon start
    sleep 1m
    if $(saptune daemon status | grep -qw "${solution}");then
        info_log "Solution(${solution}) has been applied successfully"
    fi
}

#Define HANA_post function
function HANA_post(){
    info_log "Start HANA post action"
    post HANA
}

#Define APP_post function
function APP_post(){
    info_log "Start S4 HANA post action" 
    post S4HANA-APPSERVER
}

#Define NW_post function
function NW_post(){
    info_log "Start NetWeaver post action" 
    post NETWEAVER
}

#Define metrics_collector_install
function metrics_collector_install(){
    info_log "Start to install metrics collector"
    pip install --upgrade pip
    if $(pip show pytz | grep -q pytz);then
        info_log 'package(pytz) already installed'
    else
        pip install pytz || return 1
    fi

    if $(aliyun_installer -o ecs-metrics-collector | grep -q ecs-metrics-collector);then
        info_log 'package(ecs-metrics-collector) already installed'
    else
        package_id=$(aliyun_installer -l | grep ecs-metrics-collector | sort -k 3r | head -1 | awk '{print $1}')
        echo ${package_id} | aliyun_installer -i ecs-metrics-collector
    fi

    systemctl restart ecs_metrics_collector.service
    systemctl status ecs_metrics_collector || warning_log "Metric collector didn't install please check..."
}

#Define wait_HANA_ECS function
#wait_HANA_ECS HANAPrivateIpAddress HANAInstanceNumber
function wait_HANA_ECS(){
    info_log "Start to check HANA instance status" 
    for num in $(seq 1 12)
    do 
        if [[ -n "$(echo "" | telnet $1 "3"$2"15" 2>/dev/null |grep "Escape character is")" ]]; then
            info_log "HANA instance is running now"
            return 0
        else 
            info_log "Check HANA instance status -${num}- times" 
        fi
        sleep 5m
    done
    error_log "HANA instance check timeout"
    return 1
}

# Define validation_hana function
# validation_hana HANASID HANAInstanceNumber
function validation_hana(){
    info_log "Start to validate HANA instance installation"
    sid=$(echo "$1" |tr '[:upper:]' '[:lower:]')
    sid_adm=$(echo ${sid}\adm)
    instance_number=$2
    su - "${sid_adm}" -c "sapcontrol -nr ${instance_number} -function GetProcessList" > /dev/null 2>&1
    indexserver=$?
    if [ "$indexserver" == '3' ];
    then
        info_log "HANA instance is running"
    else
        su - "${sid_adm}" -c "sapcontrol -nr ${instance_number} -function StartSystem" > /dev/null 2>&1
        for num in $(seq 1 5)
        do 
            sleep 1m
            su - "${sid_adm}" -c "sapcontrol -nr ${instance_number} -function GetProcessList" > /dev/null 2>&1
            indexserver=$?
            if [ "$indexserver" == '3' ];then
                return 0
            fi
        done
        error_log "HANA instance status is unknown"
        return 1
    fi
}


######################################################################
# Installation related functions
######################################################################
# Define get_install_mode function
# get_install_mode
function get_install_mode(){
    echo "${INFO}"
    read -t 30 -p "Enter selected action index:" install_mode
    echo -e "\n"
    case "${install_mode}" in
    1)
        InstallMode=1;;
    2)
        InstallMode=2;;
    3)
        exit 0;;
    *)
        echo "Action index error: ${install_mode}"
        exit 1;;
    esac
}

# Define init_options function
# init_options
function init_options(){
    eval set -- `getopt -o hvf:s: -l help,config-file:,step: -n "$0" -- "$@"`
    if [ $# -lt 1 ];then
        help
    fi
    while true
    do
        case "$1" in
            -h| --help)
                help;;
            -v| --version)
                show_version;;
            -f| --config-file)
                ConfigPara="$2";
                shift 2;;
            -s| --step)
                Step="$2";
                shift 2;;
            -- ) shift; break ;;
            *) echo "Unknow parameter($1)"; exit 1 ;;
        esac
    done

    if [[ -n "${ConfigPara}" ]];then
        if [[ -s "${ConfigPara}" ]];then
            source "${ConfigPara}"
            if [[ $? -ne 0 ]]
            then
                error_log "Please check parameters template file(${ConfigPara})."
            fi
        else
            error_log "Missing parameters template file(${ConfigPara})."
            exit 1
        fi
    else
        error_log "Must specify parameter '-f' or '--config-file'."
        exit 1
    fi

    if [[ -z "${Step}" ]]
    then
        get_install_mode
    elif [[ "${Step}" -eq 0 ]]
    then
        InstallMode=1
    elif [[ "${Step}" -gt 0 ]] && [[ "${Step}" -le "${QUICKSTART_LATEST_STEP}" ]]
    then
        InstallMode=3
    elif [[ "${Step}" -eq "$((QUICKSTART_LATEST_STEP + 1))" ]]
    then
        exit 0
    else
        error_log "Step Error: ${Step}"
        exit 1
    fi

    case "${InstallMode}" in
        1)
            AutoInstallMode=true
            CLIInstallMode=false;;
        2)
            AutoInstallMode=false
            CLIInstallMode=true;;
        3)
            AutoInstallMode=false
            CLIInstallMode=false;;
        *)
            echo "Action index error: ${InstallMode}"
            exit 1;;
    esac
}

# Define cli_install function
# cli_install
function cli_install(){
    while true
    do
        echo "${STEP_INFO}"
        read -t 30 -p "Enter selected action index:" install_step
        echo -e "\n"
        if [[ "${install_step}" -eq "$((QUICKSTART_LATEST_STEP + 1))" ]]
        then
            exit 0
        elif [[ "${install_step}" -gt 0 ]] && [[ "${install_step}" -le "${QUICKSTART_LATEST_STEP}" ]]
        then
            run "${install_step}" || return 1
        else
            error_log "Error index: ${install_step}"
            exit 1
        fi
        
    done
}

# Define auto_install function
# auto_install
function auto_install(){
    local mark=$(cat $QUICKSTART_SAP_MARK)
    
    local latest_step="${QUICKSTART_LATEST_STEP}"
    if [[ -n "${mark}" ]]
    then
        if [[ "${mark}" -eq 'End' ]]
        then
            echo "Already installed, if you want to install again, please execute the 'rm ${QUICKSTART_SAP_MARK}' command first."
            exit 0
        else
            local install_step="${mark}"
        fi
    else
        local install_step=1
    fi
    while true
    do
        echo "${install_step}" > "${QUICKSTART_SAP_MARK}"
        run "${install_step}" || return 1
        if [[ "${install_step}" -eq "${latest_step}" ]]
        then
            echo "End" > "${QUICKSTART_SAP_MARK}"
            break
        else
            install_step="$((install_step+1))"
        fi
    done
}

# Define pre_install function
# pre_install
function pre_install(){
    print_params
    init_env
    init_variable
    check_params
    os_pre
}

# Define install function
# install
function install(){
    init_options $@
    pre_install
    info_log "Start to implement installation script"
    if ${AutoInstallMode}
    then
        auto_install || EXIT 1
        EXIT 0
    elif ${CLIInstallMode}
    then
        cli_install || return 1
    else
        run "${Step}" || return 1
    fi
}
