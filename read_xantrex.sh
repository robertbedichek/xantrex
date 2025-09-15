#! /bin/bash

DATA_DIR=/var/log/xantrex
Xantrex_name=xantrex
Xantrex_port=80
SOC_FILE=${DATA_DIR}/soc.txt

# Two 48V strings of DC6-400.  Watt hours = 48 * 2 * 400
BATTERY_WATT_HOURS=40000

/Users/robertbedichek/Documents/Arduino/xantrex/sample_xantrex.py >>${DATA_DIR}/xantrex_inverter.xml.temp 2> /dev/null

if [ -s "${DATA_DIR}/xantrex_inverter.xml.temp" ]; then
  mv ${DATA_DIR}/xantrex_inverter.xml.temp ${DATA_DIR}/xantrex_inverter.xml

  echo -n `date +"%b %d %H:%M:%S %Y"` >${DATA_DIR}/xantrex.data

# First, the inverter's DC input voltage and current

  DCV=`cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"DCV\"    | sed -e 's/.*value="\([0-9\.-]*\)".*/ \1 /' |tr '\n' ' '`
  echo -n ' ' ${DCV} >>${DATA_DIR}/xantrex.data

  DCI=`cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"DCI\"    | sed -e 's/.*value="\([0-9\.-]*\)".*/ \1 /' |tr '\n' ' '` 
  echo -n ' ' ${DCI} >>${DATA_DIR}/xantrex.data

  if [[ ! -e ${SOC_FILE} ]]; then
    echo ${BATTERY_WATT_HOURS} >${SOC_FILE}
  fi
  SOC=`cat ${SOC_FILE}`
  NEW_SOC=${SOC}
  if [[ ${DCV} -gt 53 ]]; then
    NEW_SOC=${BATTER_WATT_HOURS}
  else
    if [[ ${DCI} -lt 0 ]]; then
      # Number of watt-hours used in the previous two minute interval
      WATT_HOURS=$(echo "scale=2; $DCV * $DCI / 30.0" | bc)

      NEW_SOC=$(echo "scale=2; $SOC + $WATT_HOURS" | bc)
      echo ${NEW_SOC} > ${SOC_FILE}
    fi
  fi

# The inverter's AC1 (Utility)
  cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"ACI\"    | sed -e 's/.*value="\([0-9\.-]*\)".*/ \1 /' |tr '\n' ' ' >>${DATA_DIR}/xantrex.data
  cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"ACV\"    | sed -e 's/.*value="\([0-9-]*\).*/ \1 /'    |tr '\n' ' ' >>${DATA_DIR}/xantrex.data

# The inverter's Load (critical output)
  cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"ACOutI\" | sed -e 's/.*value="\([0-9\.-]*\)".*/ \1 /' |tr '\n' ' ' >>${DATA_DIR}/xantrex.data
  cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"ACOutV\" | sed -e 's/.*value="\([0-9\.-]*\)".*/ \1 /' |tr '\n' ' ' >>${DATA_DIR}/xantrex.data
  echo $(echo "scale=2; $NEW_SOC * 100.0 / $BATTERY_WATT_HOURS" | bc)  >>${DATA_DIR}/xantrex.data


 if [[ "$(/bin/date +%M)" = 0 ]]; then
   echo "# Date     Time     DCV  DCI AC-In-Amps AC-In-Volts  AC-Out-Amps AC-Out-Volts" | /usr/bin/env ssh -i $HOME/.ssh/id_rsa root@bedichek.org "cat >> /var/www/html/home/xantrex.txt"
 fi
 cat ${DATA_DIR}/xantrex.data | /usr/bin/env ssh -i $HOME/.ssh/id_rsa root@bedichek.org "cat >> /var/www/html/home/xantrex.txt"

fi
