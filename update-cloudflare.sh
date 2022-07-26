#!/bin/bash
#This file should be 700 access IT CONTAINS YOUR CF API DETAILS!
# CHANGE THESE
#Potentially you could alter to accept arguments and have dymaic variables, but do not pass the auth_ variables via arguments as they will show on pslist in plain text!
auth_email="CLOUDFLARE_LOGIN_EMAIL"
auth_key="CLOUDFLARE_API_KEY" # found in cloudflare account settings
zone_name="CLOUDFLARE_ZONE_NAME (ex: yourdomain.com)"
record_name="CLOUDFLARE_RECORD_NAME (ex: ddns.yourdomain.com)"
proxied="false"

# MAYBE CHANGE THESE
ip=$(curl -s http://ipv4.icanhazip.com)

#These files should be 600 access as they contain sensitive IDs/API data. 

ip_file="/root/cloudflare/ip_v.txt" 
#stores last known update

id_file="/root/cloudflare/cloudflare_v.ids"
#id file has to be two lines with zone identifier from cloudflare on the top line and record identifier on the bottom line.
#script will get this from the cloudflare API if it isn't correct

log_file="/root/cloudflare/cloudflare_v.log"
#may contain sensitive api error dump data

#LOGGER
log() {
if [ "$1" ]; then
echo -e "[$(date) - $1" >> $log_file
fi
}




if [ -z $ip ]
then
log "Connection Error to the internet"
ip=$(cat $ip_file)
exit 1
fi



# SCRIPT START
log "Check Initiated on $record_name"
#Check current ip from icanhazip.com with last logged IP
if [ -f $ip_file ]; then
    old_ip=$(cat $ip_file)
    if [ $ip == $old_ip ]; then
        #No Change In IP
        exit 0
    fi
fi

if [ -f $id_file ] && [ $(wc -l $id_file | cut -d " " -f 1) == 2 ]; then
    zone_identifier=$(head -1 $id_file)
    record_identifier=$(tail -1 $id_file)
else
    zone_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
    record_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')
    echo "$zone_identifier" > $id_file
    echo "$record_identifier" >> $id_file
fi

update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" --data "{\"id\":\"$zone_identifier\",\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$ip\",\"proxied\":$proxied}")

if [[ $update == *"\"success\":false"* ]]; then
    message="API UPDATE FAILED. DUMPING RESULTS:\n$update"
    log "$message"
    exit 1
else
    message="IP changed to: $ip"
    echo "$ip" > $ip_file
    log "$message"
fi
