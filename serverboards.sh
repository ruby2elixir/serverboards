#!/bin/sh

cd $( dirname $0 )

case "$1" in
  start)
    cd backend
    MIX_ENV=prod mix run --no-halt
  ;;
  stop)
    echo "Not yet"
  ;;
  test)
    make -j2 -m test
  ;;
  *)
    echo "start|stop"
  ;;
esac
