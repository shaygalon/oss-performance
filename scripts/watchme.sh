tick=30
last=`curl http://localhost:8090/nginx_status 2>&1 | tail -2 | head -1 | cut -f 2 -d ' '`
if [ -z "$last" ] ; then last=0 ; fi
for i in {1..100000} ; do 
	cur=`curl http://localhost:8090/nginx_status 2>&1 | tail -2 | head -1 | cut -f 2 -d ' '`
	if [ ! -z "$cur" ] ; then
		RPS=$[($cur-$last)/$tick]
		echo "RPS=$RPS"
	fi 
	last=$cur
	sleep $tick
done

