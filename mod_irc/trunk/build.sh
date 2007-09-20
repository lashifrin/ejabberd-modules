#!/bin/sh
if [ -z "$MAKE" ]; then
  MAKE=make
fi

$MAKE
erl -pa ../../../ejabberd-dev/trunk/ebin -pz ebin -make
