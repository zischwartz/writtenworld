#!/bin/bash

# This file kills any currently running processes, and then starts all of them up.
# Used to start the ruby app, python app, and redis.
#

HOME_DIR=~/Sites/scribverse
TODAY=`date '+%m-%d-%Y'`

# Check if there is already a logs directory; if not, create it
#
if [ `ls $HOME_DIR | grep -c logs` == 0 ];  
  then   
    mkdir $HOME_DIR/logs
fi

# For each process, check to see if it's already running; if so, kill it and wait 5 seconds for it to stop.
# Then start up the process again using nohup to keep it running; write output of process to log file.
# After that, check to make sure it's really running, and print the status to stdout.
#
declare -a processes=(ruby python2.7 redis-server)
declare -a file_names=('nyt-timelines/main.rb' 'nyt-timelines-nlp/nltk_server.py' redis-server)

for (( x=0 ; x < ${#processes[@]}; x++ ))
do
  if [ `ps -eo pid,args | grep -v grep | grep -c "${file_names[$x]}"` -gt 0 ];
  then
    PID=`ps -eo pid,args | grep -v grep | grep "${file_names[$x]}" | awk '{print $1;}'`
    kill $PID
    
    #wait to make the sure the process has really stopped
    while [ `ps -eo pid,args | grep -v grep | grep -c "${file_names[$x]}"` -gt 0 ]
    do
      sleep 1
    done
  fi  
  
  if [ "${processes[$x]}" != 'redis-server' ];  
  then
    nohup "${processes[$x]}" $HOME_DIR/"${file_names[$x]}" >>$HOME_DIR/logs/"${processes[$x]}"_log_$TODAY &
  else
    nohup "${processes[$x]}" >>$HOME_DIR/logs/"${processes[$x]}"_log_$TODAY &
  fi
  
  if [ `ps -eo pid,args | grep -v grep | grep -c "${file_names[$x]}"` -gt 0 ];
  then
    echo "${file_names[$x]}" is running.
  else
    echo "${file_names[$x]}" did not start up.
    echo `tail -50 $HOME_DIR/logs/"${processes[$x]}"_log_$TODAY`
  fi
done  
