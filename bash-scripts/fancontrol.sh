#!/usr/bin/env bash
#set -x
IPMIHOST=  #IP for the idrac 
IPMIUSER=  #Idrac user name
IPMIPW=  #idrac password 
IPMIEK=0000000000000000000000000000000000000000

FANSPEEDHEX="0x08"
MAXTEMP=60
HYSTERESIS=12

FANFILE= #path to fan file

function ipmi() {
        ipmitool -I lanplus -H "$IPMIHOST" -U "$IPMIUSER" -P "$IPMIPW" "$@"
}

if ! TEMPS=$(ipmi sdr type temperature | grep -vi inlet | grep -vi exhaust | grep -Po '\d{2,3}' 2>&1); then
        echo "$(date): FAILED TO READ TEMPERATURE SENSOR: $TEMP" >> "$FANFILE" 
fi

HIGHTEMP=0
LOWTEMP=1

for TEMP in $TEMPS; do
        if [[ $TEMP > $MAXTEMP ]]; then
                HIGHTEMP=1
        fi
        if [[ $TEMP > $((MAXTEMP - HYSTERESIS)) ]]; then
                LOWTEMP=0
        fi
done

if [[ $HIGHTEMP == 1 ]]; then
        #Automatic fan control
        ipmi raw 0x30 0x30 0x01 0x01; echo "$(date): Set Fan Control Mode to Automatic" >> "$FANFILE" || echo "$(date): FAILED TO SET AUTOMATIC FAN CONTROL MODE" >> "$FANFILE"
elif [[ $LOWTEMP == 1 ]]; then
        #Manual fan control
        ipmi raw 0x30 0x30 0x01 0x00; echo "$(date): Set Fan Control Mode to Manual" >> "$FANFILE" || echo "$(date): FAILED TO SET MANUAL FAN CONTROL MODE" >> "$FANFILE"
        ipmi raw 0x30 0x30 0x02 0xff "$FANSPEEDHEX"; echo "$(date): Set Fan Control Speed to $FANSPEEDHEX" >> "$FANFILE" || echo "$(date): FAILED TO SET FAN SPEED" >> "$FANFILE"
fi
