#!/bin/bash
#
# chkconfig: 345 99 55
# description: MyEngine Service
# Init file for MyEngine
#

source /etc/rc.d/init.d/functions

### Default variables
OPTIONS=""

### Read configuration
[ -r "$SYSCONFIG" ] && source "$SYSCONFIG"

RETVAL=0
prog="samplelogging_start"
desc="Sample Logging Engine"
pidfile="/var/run/sampleLogging.pid"

start() {
	echo -n $"Starting $desc ($prog): "
	daemon --pidfile ${pidfile} $prog $OPTIONS
	RETVAL=$?
	echo
	[ $RETVAL -eq 0 ] && touch /var/lock/subsys/$prog
	return $RETVAL
}

stop() {
	echo -n $"Shutting down $desc ($prog): "
	killproc -p ${pidfile} $prog
	RETVAL=$?
	echo
	[ $RETVAL -eq 0 ] && rm -f /var/lock/subsys/$prog ${pidfile}
	return $RETVAL
}

restart() {
	stop
	start
}


case "$1" in
  start)
	start
	;;
  stop)
	stop
	;;
  restart)
	restart
	;;
  condrestart)
	[ -e /var/lock/subsys/$prog ] && restart
	RETVAL=$?
	;;
  status)
	status -p ${pidfile}  $prog
	RETVAL=$?
	;;
   *)
	echo $"Usage: $0 {start|stop|restart}"
	RETVAL=1
esac

exit $RETVAL
