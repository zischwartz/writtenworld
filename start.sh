#!/bin/sh

echo 'Starting shit up...'


FIRST_ARGUMENT="$1"
echo "Hello, world $FIRST_ARGUMENT!"

echo ' To quit redis: '
echo ' redis-cli shutdown'
redis-server & 

nodemon app.coffee &
# was just nodemon app.coffee &

# not using these, for shutting down individually. kill 0 works for group great!
# NODEMON_PID="$!"
# echo "nodemon pid: $NODEMON_PID"
# echo $!

coffee --watch --compile nownow.coffee models.coffee public/ &

mongod

read RESP
if [ "$RESP" = "c" ]; then
  echo 'SHUTTING IT DOWN!'
  trap "kill 0" SIGINT SIGTERM EXIT
fi


function pidactive () {
    #sends a signal which checks if the process is active (doesn't kill anything)
    kill -0 $1 2> /dev/null
    return
}

function pidkill () {
    echo "killing pid"
    kill $1 || return
    #adjust depending how long it takes to die gracefully
    sleep 1
    if pidactive $1; then
        #escalating
        kill -9 $1
    fi  
}
