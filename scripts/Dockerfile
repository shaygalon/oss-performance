FROM ubuntu:16.04

MAINTAINER Shay Gal-On <sgalon@cavium.com>

ENV HHVM_TAG=4b7842e59e2e3313c4a2b2983c4c0280467b78f2

RUN apt update -y && apt-get install -y software-properties-common apt-transport-https && \
	apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xB4112585D386EB94 && \
	add-apt-repository -s https://dl.hhvm.com/ubuntu && \
	apt update -y 
	
RUN DEBIAN_FRONTEND=noninteractive && apt-get install -y sudo vim autoconf automake binutils-dev build-essential cmake g++ gawk git \
 libboost-dev libboost-filesystem-dev libboost-program-options-dev libboost-regex-dev \
 libboost-system-dev libboost-thread-dev libboost-context-dev libbz2-dev libc-client-dev libldap2-dev \
 libc-client2007e-dev libcap-dev libcurl4-openssl-dev libdwarf-dev libelf-dev \
 libexpat-dev libgd2-xpm-dev libgoogle-glog-dev libgoogle-perftools-dev libicu-dev \
 libjemalloc-dev libmcrypt-dev libmemcached-dev libmysqlclient-dev libncurses-dev \
 libonig-dev libpcre3-dev libreadline-dev libtbb-dev libtool libxml2-dev zlib1g-dev \
 libevent-dev libmagickwand-dev libinotifytools0-dev libiconv-hook-dev libedit-dev \
 libiberty-dev libxslt1-dev ocaml-native-compilers libsqlite3-dev libyaml-dev libmpc-dev \
 gperf libkrb5-dev libnotify-dev libdouble-conversion-dev zlib1g-dev libdouble-conversion-dev locales tzdata

ENV TZ=America/Los_Angeles
RUN echo "$TZ" > /etc/timezone && ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && \
	for l in en_EN en_UK en_US en_GB de_DE fr_FR fa_IR zh_CN.utf8 zh_CN ; do \
	locale-gen $l || true ; done 

# mysql first time will fail to start after install due to permissions.
RUN bash -c "debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'" && \
	bash -c "debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'" && \
	apt install -y mysql-server nginx curl wget php && \
	echo "max_connections        = 1000" >> /etc/mysql/mysql.conf.d/mysqld.cnf && \
	( chown -R mysql:mysql /var/lib/mysql /var/run/mysqld || true ) && find /var/lib/mysql -type f -exec touch {} \; && \
	( service mysql start || true ) && \
	( chmod 766 /var/log/nginx/error.log || true )

RUN sed -i.bkp -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers && \
	echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config && \
	useradd -ms /bin/bash cavium && echo "cavium:cavium" | chpasswd && adduser cavium sudo && \
	echo "* soft nofile 999999" >> /etc/security/limits.conf && \
	echo "* hard nofile 999999" >> /etc/security/limits.conf

RUN chmod a+w /opt
WORKDIR /opt

RUN git clone https://github.com/JoeDog/siege.git && cd siege && git checkout tags/v4.0.3rc3 && \
	./utils/bootstrap && automake --add-missing && \
	./configure && make -j && make install && \
	cd .. && rm -rf siege

RUN git clone https://github.com/jemalloc/jemalloc.git && cd jemalloc && git checkout 4.5.0 && \
	./autogen.sh && make -j && ( make install || true ) && ln -s /usr/local/lib/libjemalloc.so.2 /usr/lib/aarch64-linux-gnu && \
	cd .. && rm -rf jemalloc

RUN ( chown -R mysql:mysql /var/lib/mysql /var/run/mysqld || true ) && find /var/lib/mysql -type f -exec touch {} \; && \
	service mysql restart && \
	mysql -u root -h localhost --port 3306 --password=root -e "SET GLOBAL max_connections = 1000;" && \
	for db in mw_bench drupal_bench wp_bench ; do \
	mysql -u root -h localhost --port 3306 --password=root -e "CREATE DATABASE $db;" && \
	mysql -u root -h localhost --port 3306 --password=root -e "CREATE USER '$db'@'localhost' IDENTIFIED BY '$db';" && \
	mysql -u root -h localhost --port 3306 --password=root -e "GRANT ALL PRIVILEGES ON $db.* TO $db@'%' IDENTIFIED BY '$db';" ; \
	done && \
	service mysql stop

EXPOSE 8091
EXPOSE 8092
EXPOSE 8093
 
USER cavium
RUN git clone https://github.com/hhvm/oss-performance.git
RUN git clone https://github.com/facebook/hhvm.git && cd hhvm && git checkout $HHVM_TAG && git submodule update --init --recursive 
	 
WORKDIR /opt/hhvm
RUN cmake -DENABLE_LD_GOLD=Off -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/opt/hhvm-$HHVM_TAG \
	-DMYSQL_UNIX_SOCK_ADDR=/var/run/mysqld/mysqld.sock \
	-DENABLE_AARCH64_CRC=1 -DAARCH64_TARGET_CPU=native . && \
	make -j && make install

WORKDIR /opt/oss-performance
RUN wget https://getcomposer.org/installer && php installer && export PATH=/opt/hhvm/hphp/hhvm/:$PATH && ./composer.phar install

#If mysql is installed on the host disable mysql in apparmor on the host:
# sudo ln -s /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.d/disable
# sudo apparmor_parser -R /etc/apparmor.d/usr.sbin.mysqld
#docker build -t oss .
#run docker with --privileged --sysctl net.ipv4.tcp_tw_reuse=1 -it oss bash
# Optionally add -v <path to hhvm>:/opt/hhvm if using a different version of hhvm instead of the one built in the container.
# In the docker start mysql as 
#  sudo find /var/lib/mysql -type f -exec touch {} \; && sudo service mysql restart
# * May fail first time depending on what storage options are used for docker, just repeat if it fails, second time will pass.
# run /opt/hhvm/hphp/hhvm/hhvm perf.php --i-am-not-benchmarking --trace --<test> --hhvm=/opt/hhvm/hphp/hhvm/hhvm 

