#! /bin/bash

Old_Enphase_name="enphase2015"
Old_Enphase_port="80"
New_Enphase_name="enphase2021"

DATA_DIR=/var/log/xantrex
Xantrex_name=xantrex
Xantrex_port=80
SOC_FILE=${DATA_DIR}/soc.txt
CURL=/usr/bin/curl
XANTREX_DIR=/Users/robertbedichek/Documents/Arduino/xantrex
TOKEN=`cat ${XANTREX_DIR}/token.txt`

# Two 48V strings of DC6-400.  Watt hours = 48 * 2 * 400
BATTERY_WATT_HOURS=40000

 if [[ "$(/bin/date +%M)" = 00 ]]; then
   echo "# Date     Time     DCV  DCI AC-In-Amps AC-In-Volts  AC-Out-Amps AC-Out-Volts SoC Enphase2015-kW Enphase2021-kW" | /usr/bin/env ssh -i $HOME/.ssh/id_rsa root@bedichek.org "cat >> /var/www/html/home/xantrex.txt"
 fi

/bin/rm -f ${DATA_DIR}/xantrex_inverter.xml.temp ${DATA_DIR}/xantrex_inverter.xml
${XANTREX_DIR}/sample_xantrex.py >>${DATA_DIR}/xantrex_inverter.xml.temp 2> /dev/null

if [ -s "${DATA_DIR}/xantrex_inverter.xml.temp" ]; then
  mv ${DATA_DIR}/xantrex_inverter.xml.temp ${DATA_DIR}/xantrex_inverter.xml

  echo -n `date +"%Y-%m-%d %H:%M:%S"` >${DATA_DIR}/xantrex.data

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

  fgt() { echo "$1 > $2" | bc -l; }
  flt() { echo "$1 < $2" | bc -l; }
  
  if (( $(fgt "$DCV" 53) )); then
    # (verify this var name—did you mean BATTERY_WATT_HOURS?)
    NEW_SOC="${BATTERY_WATT_HOURS}"
  else
    if (( $(flt "$DCI" 0) )); then
      # Watt-hours over a 2-minute interval
      WATT_HOURS=$(echo "$DCV * $DCI / 30" | bc -l)
  
      NEW_SOC=$(echo "$SOC + ($WATT_HOURS)" | bc -l)
  
      # write with 2 decimals
      printf '%.2f\n' "$NEW_SOC" > "$SOC_FILE"
    fi
  fi
  
# The inverter's AC1 (Utility)
  cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"ACI\"    | sed -e 's/.*value="\([0-9\.-]*\)".*/ \1 /' |tr '\n' ' ' >>${DATA_DIR}/xantrex.data
  cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"ACV\"    | sed -e 's/.*value="\([0-9-]*\).*/ \1 /'    |tr '\n' ' ' >>${DATA_DIR}/xantrex.data

# The inverter's Load (critical output)
  cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"ACOutI\" | sed -e 's/.*value="\([0-9\.-]*\)".*/ \1 /' |tr '\n' ' ' >>${DATA_DIR}/xantrex.data
  cat ${DATA_DIR}/xantrex_inverter.xml          | egrep \"ACOutV\" | sed -e 's/.*value="\([0-9\.-]*\)".*/ \1 /' |tr '\n' ' ' >>${DATA_DIR}/xantrex.data

  echo -n $(echo "scale=2; $NEW_SOC * 100.0 / $BATTERY_WATT_HOURS" | bc)  >>${DATA_DIR}/xantrex.data

  # This script is run every two minutes by a cron job.  Here we poll the Enphase
  # communications gateway, extract the information, put
  # it into a gnuplot-compatible format, and create a new plot.
  
  /bin/rm -f ${DATA_DIR}/old_enphase.temp ${DATA_DIR}/old_enphase.http

  ${CURL} -s http://${Old_Enphase_name}:${Old_Enphase_port}/home >${DATA_DIR}/old_enphase.temp 2> /dev/null
  
  if [ -s "${DATA_DIR}/old_enphase.temp" ]; then
    mv ${DATA_DIR}/old_enphase.temp ${DATA_DIR}/old_enphase.http
    egrep 'Currently generating'  ${DATA_DIR}/old_enphase.http  >${DATA_DIR}/old_enphase.line
  
  # $DATA_DIR/old_enphase.line is a one-line file like this:
  #
  #            <tr><td>Lifetime generation</td>    <td> 27.8 kWh</td></tr><tr><td>Currently generating</td>    <td>    0 W</td></tr>
  #
  # The "currently generating" field can be Watts or kilo-Watts.  We have to determine which
  
    egrep ' W</td>' ${DATA_DIR}/old_enphase.line >/dev/null
  
    if [ "$?" == "0" ]; then

      # Parse assuming the number is in Watts (because we found "W</td>" e.g.:
      # <tr><td>Lifetime generation</td>    <td> 88.6 MWh</td></tr><tr><td>Currently generating</td>    <td>  70.0 W</td></tr>

      OLD_ENPHASE_KW=`cat ${DATA_DIR}/old_enphase.line | sed -e 's/.*generating<\/td> *<td> *\([0-9\.]*\) W.*/\1/'`
      OLD_ENPHASE_KW=`echo "scale=3; $OLD_ENPHASE_KW / 1000.0" | bc -l`
    else
      # Parse assuming the number is in kilo Watts (because we didn't find a "W</td>"
      OLD_ENPHASE_KW=`cat ${DATA_DIR}/old_enphase.line | sed -e 's/.*generating<\/td> *<td> *\([0-9\.]*\) kW.*/\1/'`
    fi
  
    echo -n " ${OLD_ENPHASE_KW}" >>${DATA_DIR}/xantrex.data
  fi
  ${CURL} -fsSk -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" "https://${New_Enphase_name}/api/v1/production" | jq . >${DATA_DIR}/new_enphase.json
  if [ -s "${DATA_DIR}/new_enphase.json" ]; then
    NEW_ENPHASE_W=`jq -r '.wattsNow // 0' ${DATA_DIR}/new_enphase.json`

    NEW_ENPHASE_KW=$(echo "scale=2; $NEW_ENPHASE_W / 1000.0" | bc)
    echo -n " ${NEW_ENPHASE_KW}" >>${DATA_DIR}/xantrex.data
  fi

  echo "" >>${DATA_DIR}/xantrex.data

  cat ${DATA_DIR}/xantrex.data | /usr/bin/env ssh -i $HOME/.ssh/id_rsa root@bedichek.org "cat >> /var/www/html/home/xantrex.txt"

fi
