FROM ubuntu:16.04

MAINTAINER Shay Gal-On <sgalon@cavium.com>

ENV HHVM_TAG=ae5f4da564f461c1fb0652a431f7b6206f1f7047
ENV JEMALLOC_TAG=4.5.0
ENV SIEGE_TAG=tags/v4.0.3rc3

RUN apt update -y && apt-get install -y software-properties-common apt-transport-https && \
	apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xB4112585D386EB94 && \
	add-apt-repository -s https://dl.hhvm.com/ubuntu && \
	apt update -y 

#hhvm dependecies
RUN DEBIAN_FRONTEND=noninteractive && apt-get -y build-dep hhvm-nightly && \
 apt install -y sudo vim gawk git zip unzip curl wget php ssh \
 camlp4 ledit libcamlp4-ocaml-dev libdouble-conversion-dev \
 libdouble-conversion1v5 libfindlib-ocaml libfindlib-ocaml-dev libgpm2 \
 libmpc-dev libmpfr-dev libmysqlclient-dev libmysqlclient20 libpython3.5 \
 libreadline-dev libreadline6-dev locales mysql-common ocaml-base-nox \
 ocaml-compiler-libs ocaml-findlib ocaml-interp ocaml-native-compilers \
 ocaml-nox 

#setup timezone to pacific
ENV TZ=America/Los_Angeles
RUN echo "$TZ" > /etc/timezone && ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && \
	for l in en_EN en_UK en_US en_GB de_DE fr_FR fa_IR zh_CN.utf8 zh_CN ; do \
	locale-gen $l || true ; done 

#mysql install and permissions for oss-performance use of nginx
RUN bash -c "debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'" && \
	bash -c "debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'" && \
	apt install -y mysql-server nginx && \
	( chown -R mysql:mysql /var/lib/mysql /var/run/mysqld || true ) && find /var/lib/mysql -type f -exec touch {} \; && \
	( service mysql start || true ) && \
	( chmod 766 /var/log/nginx/error.log || true )

#mysql setup for oss-performance
RUN ( chown -R mysql:mysql /var/lib/mysql /var/run/mysqld || true ) && find /var/lib/mysql -type f -exec touch {} \; && \
	echo "max_connections        = 1000" >> /etc/mysql/mysql.conf.d/mysqld.cnf && \
	service mysql restart && \
	mysql -u root -h localhost --port 3306 --password=root -e "SET GLOBAL max_connections = 1000;" && \
	for db in mw_bench drupal_bench wp_bench ; do \
	mysql -u root -h localhost --port 3306 --password=root -e "CREATE DATABASE $db;" && \
	mysql -u root -h localhost --port 3306 --password=root -e "CREATE USER '$db'@'localhost' IDENTIFIED BY '$db';" && \
	mysql -u root -h localhost --port 3306 --password=root -e "GRANT ALL PRIVILEGES ON $db.* TO $db@'%' IDENTIFIED BY '$db';" ; \
	done && \
	service mysql stop

#add non-root user
RUN sed -i.bkp -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers && \
	echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config && \
	useradd -ms /bin/bash cavium && echo "cavium:cavium" | chpasswd && adduser cavium sudo && \
	echo "* soft nofile 999999" >> /etc/security/limits.conf && \
	echo "* hard nofile 999999" >> /etc/security/limits.conf

RUN chmod a+w /opt
WORKDIR /opt

#version of siege that works with oss
RUN git clone https://github.com/JoeDog/siege.git && cd siege && git checkout $SIEGE_TAG && \
	./utils/bootstrap && automake --add-missing && \
	./configure && make -j && make install && \
	cd .. && rm -rf siege

#jemalloc.so.2, using a specific version
RUN git clone https://github.com/jemalloc/jemalloc.git && cd jemalloc && git checkout $JEMALLOC_TAG && \
	./autogen.sh && make -j && ( make install || true ) && ln -s /usr/local/lib/libjemalloc.so.2 /usr/lib/aarch64-linux-gnu && \
	cd .. && rm -rf jemalloc


EXPOSE 8091
EXPOSE 8092
EXPOSE 8093

COPY entry.sh /usr/local/bin/entry.sh
RUN chmod +x /usr/local/bin/entry.sh

USER cavium
RUN git clone https://github.com/shaygalon/oss-performance.git
RUN git clone https://github.com/facebook/hhvm.git && cd hhvm && git checkout $HHVM_TAG && git submodule update --init --recursive 
	 
WORKDIR /opt/hhvm
RUN if [ `uname -m` = "aarch64" ] ; then \
	EXTRAS="-DENABLE_AARCH64_CRC=1 -DAARCH64_TARGET_CPU=native" ; \
	cmake -DENABLE_LD_GOLD=Off -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/hhvm-$HHVM_TAG \
	-DMYSQL_UNIX_SOCK_ADDR=/var/run/mysqld/mysqld.sock \
	$EXTRAS . && \
	make -j 16 && make install

WORKDIR /opt/oss-performance
RUN wget https://getcomposer.org/installer && php installer && export PATH=/opt/hhvm/hphp/hhvm/:$PATH && ./composer.phar install

ENTRYPOINT ["/usr/local/bin/entry.sh"]

#If mysql is installed on the host disable mysql in apparmor on the host:
# sudo ln -s /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.d/disable
# sudo apparmor_parser -R /etc/apparmor.d/usr.sbin.mysqld
#docker build -t oss .
#run docker with 
# --privileged --sysctl net.ipv4.tcp_tw_reuse=1 -t oss [--<test to run]
# or
# --privileged --sysctl net.ipv4.tcp_tw_reuse=1 -it oss bash
#privileged mode to avoid error report from hhvm
#
# Optionally add -v <path to hhvm>:/opt/hhvm if using a different version of hhvm instead of the one built in the container.
# Running if using interactive bash session
# /opt/hhvm/hphp/hhvm/hhvm perf.php --i-am-not-benchmarking --trace --<test> --hhvm=/opt/hhvm/hphp/hhvm/hhvm 

