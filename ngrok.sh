#!/bin/bash
clear
echo "┌-----------------------------------------------------------┐"
echo "|                                                           |"
echo "|                    开始搭建ngrock环境                     |"
echo "|                                                           |"
echo "└-----------------------------------------------------------┘"

# Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

read -p "请输入您的域名(例：baidu.com。注：没有www.): " url
echo "您的域名是：$url"
clear

clientNameList=(
"Linux 平台 32 位系统"
"Linux 平台 64 位系统"
"Windows 平台 32 位系统"
"Windows 平台 64 位系统"
"MAC 平台 32 位系统"
"MAC 平台 64 位系统"
"ARM 平台"
)

ngrokFile=(
"linux_386"
"linux_amd64"
"windows_386"
"windows_amd64"
"darwin_386"
"darwin_amd64"
)

echo "请选择客户端平台："
for ((i=1;i<=${#clientNameList[@]};i++ )); do
    line="${clientNameList[$i-1]}"
    echo -e "${green}${i}) ${plain}${line}"
done
read -p "${green}你的选择是: ${plain}" num

clear

read -p "${green}请选择默认http端口(默认：8080): ${plain}" httpPort
httpPort=${httpPort:-8080}
clear

read -p "${green}请选择默认https端口(默认：8081): ${plain}" httpsPort
httpsPort=${httpsPort:-8081}
clear

cd ~
# 下载环境
sudo apt-get install golang make
echo "${green}------ 下载环境完成 ------"

# 下载ngrok
cd /usr/local/
git clone https://github.com/inconshreveable/ngrok.git
export GOPATH=/usr/local/ngrok/
export NGROK_DOMAIN="ngrok.$url"
echo "------ 下载ngrok完成 ------"
cd ngrok
# 生成证书
echo "开始生成证书......"
openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -subj "/CN=$NGROK_DOMAIN" -days 5000 -out rootCA.pem
openssl genrsa -out server.key 2048
openssl req -new -key server.key -subj "/CN=$NGROK_DOMAIN" -out server.csr
openssl x509 -req -in server.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out server.crt -days 5000
# 拷贝证书
cp rootCA.pem assets/client/tls/ngrokroot.crt
cp server.crt assets/server/tls/snakeoil.crt
cp server.key assets/server/tls/snakeoil.key
echo "------ 证书生成拷贝完毕 ------"
echo " "
# 编译服务端
echo "开始编译服务端......"
echo " "
cd /usr/local/ngrok/
make release-server
echo "------ 服务端编译完毕 ------"
echo " "
# 设置环境变量
echo "开始编译客户端......"

case $num in
	1 )	export GOOS=linux GOARCH=386
		;;
	2 ) export GOOS=linux GOARCH=amd64
		;;
	3 ) export GOOS=windows GOARCH=386
		;;
	4 ) export GOOS=windows GOARCH=amd64 
		;;
	5 ) export GOOS=darwin GOARCH=386	
		;;
	6 ) export GOOS=darwin GOARCH=amd64	
		;;
	7 ) export GOOS=linux GOARCH=arm
		;;
esac

make release-client

echo "------ 客户端编译完毕 ------"
echo " "
echo "开始打包客户端......"
cd "/usr/local/ngrok/bin/${ngrokFile[${num}-1]}"
touch ngrok.cfg
cat > ./ngrok.cfg<<-EOF
server_addr: "ngrok.${url}:4443"
trust_host_root_certs: false
EOF
cd /usr/local/ngrok/bin
tar czvf ngrok.tar "./${ngrokFile[${num}-1]}"
echo "------ 客户端打包完成 ------"

# 启动服务端
/usr/local/ngrok/bin/ngrokd -domain="ngrok.${url}" -httpAddr=":${httpPort}" -httpsAddr=":${httpsPort}" -log-level="ERROR" &
echo "------ 服务端开启 ------${plain}"

clear

echo " "
echo "给pi地址配置域名DNS：${green}ngrok.******.com${plain} 和 ${green}*.ngrok.******.com${plain}"
echo "客户端输入命令：${green}scp 用户@ip:/usr/local/ngrok/bin/ngrock.tar 本地目录${plain}"
echo "本地解压后，输入：${green}./ngrok -config=./ngrok.cfg (配置文件名) -subdomain=example (域名前缀名,不加随机分配) 80 (需要穿透内网的端口名)${plain}"