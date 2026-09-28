#! /bin/bash

DATA_DIR=/var/log/xantrex

# This script is run every two minutes by a cron job.  Here we poll the Enphase
# communications gateway, extract the information, put
# it into a gnuplot-compatible format, and create a new plot.

Enphase_name="enphase"
Enphase_port="80"

curl -s http://${Enphase_name}:${Enphase_port}/home >${DATA_DIR}/enphase.temp 2> /dev/null

if [ -s "${DATA_DIR}/enphase.temp" ]; then
  mv ${DATA_DIR}/enphase.temp ${DATA_DIR}/enphase.http
  egrep 'Currently generating'  ${DATA_DIR}/enphase.http  >${DATA_DIR}/enphase.line

# $DATA_DIR/enphase.line is a one-line file like this:
#
#            <tr><td>Lifetime generation</td>    <td> 27.8 kWh</td></tr><tr><td>Currently generating</td>    <td>    0 W</td></tr>
#
# The "currently generating" field can be Watts or kilo-Watts.  We have to determine which

  egrep ' W</td>' ${DATA_DIR}/enphase.line >/dev/null

  if [ "$?" == "0" ]; then
    CURRENT_KW=`cat ${DATA_DIR}/enphase.line | sed -e 's/.*generating<\/td> *<td> *\([0-9\.]*\) W.*/0.\1/'`
  else
    CURRENT_KW=`cat ${DATA_DIR}/enphase.line | sed -e 's/.*generating<\/td> *<td> *\([0-9\.]*\) kW.*/\1/'`
  fi

  CURRENT_DATE=`date +"%b %d %H:%M:%S %Y"`

  echo "${CURRENT_DATE} ${CURRENT_KW}" >${DATA_DIR}/enphase.data

fi
