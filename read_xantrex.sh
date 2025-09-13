#! /bin/bash

DATA_DIR=/var/log/xantrex
Xantrex_name=xantrex
Xantrex_port=80

/Users/robertbedichek/Documents/Arduino/xantrex/sample_xantrex.py >>${DATA_DIR}/xantrex_inverter.xml.temp 2> /dev/null

if [ -s "${DATA_DIR}/xantrex_inverter.xml.temp" ]; then
  mv ${DATA_DIR}/xantrex_inverter.xml.temp ${DATA_DIR}/xantrex_inverter.xml

  echo -n `date +"%b %d %H:%M:%S %Y"` >${DATA_DIR}/xantrex.data

# First, the inverter's DC input voltage and current
  cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"DCV\"    | sed -e 's/.*value="\([0-9\.-]*\)".*/ \1 /' |tr '\n' ' ' >>${DATA_DIR}/xantrex.data
  cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"DCI\"    | sed -e 's/.*value="\([0-9\.-]*\)".*/ \1 /' |tr '\n' ' ' >>${DATA_DIR}/xantrex.data

# The inverter's AC1 (Utility)
  cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"ACI\"    | sed -e 's/.*value="\([0-9\.-]*\)".*/ \1 /' |tr '\n' ' ' >>${DATA_DIR}/xantrex.data
  cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"ACV\"    | sed -e 's/.*value="\([0-9-]*\).*/ \1 /'    |tr '\n' ' ' >>${DATA_DIR}/xantrex.data

# The inverter's Load (critical output)
  cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"ACOutI\" | sed -e 's/.*value="\([0-9\.-]*\)".*/ \1 /' |tr '\n' ' ' >>${DATA_DIR}/xantrex.data
  cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"ACOutV\" | sed -e 's/.*value="\([0-9\.-]*\)".*/ \1 /'  >>${DATA_DIR}/xantrex.data


 if [[ "$(date +%M)" = 0 ]]; then
   echo "# Date     Time     DCV  DCI AC-In-Amps AC-In-Volts  AC-Out-Amps AC-Out-Volts" | /usr/bin/env ssh -i $HOME/.ssh/id_rsa root@bedichek.org "cat >> /var/www/html/home/xantrex.txt"
 fi
 cat ${DATA_DIR}/xantrex.data | /usr/bin/env ssh -i $HOME/.ssh/id_rsa root@bedichek.org "cat >> /var/www/html/home/xantrex.txt"

fi
