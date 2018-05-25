#!/bin/bash

test_mysql ()
{
service="mysqld"
if (( $(ps -ef | grep -v grep | grep $service | wc -l) > 0 ))
then
echo "$service is running"
else
sudo find /var/lib/mysql -type f -exec touch {} \; && sudo service mysql start
fi
}

test_mysql
test_mysql

if [[ "$1" == "bash" ]] ; then 
	ALL_PARAMS=`echo $ALL_PARAMS | perl -p -e 's/bash//'`
	if [[ "$ALL_PARAMS" == "" ]] ; then 
		exec bash
	else 	
		exec bash "$ALL_PARAMS" 
	fi
else
	if [ -z "$1" ] ; then 
		params="--mediawiki"
	else
		params="$@"
	fi
	/opt/hhvm/hphp/hhvm/hhvm perf.php --i-am-not-benchmarking --trace $params --hhvm=/opt/hhvm/hphp/hhvm/hhvm 
fi

