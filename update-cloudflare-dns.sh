#!/usr/bin/env bash

###  Create .update-cloudflare-dns.log file of the last run for debug
parent_path="$(dirname "${BASH_SOURCE[0]}")"
FILE=${parent_path}/update-cloudflare-dns.log
if ! [ -x "$FILE" ]; then
  touch "$FILE"
fi

LOG_FILE=${parent_path}'/update-cloudflare-dns.log'

### Write last run of STDOUT & STDERR as log file and prints to screen
exec > >(tee $LOG_FILE) 2>&1
echo "==> $(date "+%Y-%m-%d %H:%M:%S")"

### Validate if config-file exists

if [[ -z "$1" ]]; then
  if ! source ${parent_path}/update-cloudflare-dns.conf; then
    echo 'Error! Missing configuration file update-cloudflare-dns.conf or invalid syntax!'
    exit 0
  fi
else
  if ! source ${parent_path}/"$1"; then
    echo 'Error! Missing configuration file '$1' or invalid syntax!'
    exit 0
  fi
fi

### Check validity of "ttl" parameter
if [ "${ttl}" -lt 60 ] || [ "${ttl}" -gt 7200 ] && [ "${ttl}" -ne 1 ]; then
  echo "Error! ttl out of range (60-7200) or not set to 1"
  exit
fi

### Check validity of "proxied" parameter
if [ "${proxied}" != "false" ] && [ "${proxied}" != "true" ]; then
  echo 'Error! Incorrect "proxied" parameter, choose "true" or "false"'
  exit 0
fi

### Valid IPv4 Regex
REIP='^((25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])\.){3}(25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])$'

### Get external ip from https://checkip.amazonaws.com
ip=$(ifstatus wan |  jsonfilter -e '@["ipv4-address"][0].address')
  if [ -z "$ip" ]; then
    echo "Error! Can't get ip"
    exit 0
  fi
  if ! [[ "$ip" =~ $REIP ]]; then
    echo "Error! IP Address returned was invalid!"
    exit 0
  fi
echo "==> IP is: $ip"

### Build coma separated array fron dns_record parameter to update multiple A records
IFS=',' read -d '' -ra dns_records <<<"$dns_record,"
unset 'dns_records[${#dns_records[@]}-1]'
declare dns_records

for record in "${dns_records[@]}"; do
  ### Get IP address of DNS record from 1.1.1.1 DNS server when proxied is "false"
  if [ "${proxied}" == "false" ]; then
    ### Check if "nslookup" command is present
    if which nslookup >/dev/null; then
      dns_record_ip=$(nslookup ${record} | awk '/Address/ { print $2 }' | sed -n '2p')
    else
      ### if no "nslookup" command use "host" command
      dns_record_ip=$(host -t A ${record} | awk '/has address/ { print $4 }' | sed -n '1p')
    fi

    if [ -z "$dns_record_ip" ]; then
      echo "Error! Can't resolve ${record} "
      exit 0
    fi
    is_proxed="${proxied}"
  fi

  ### Get the dns record id and current proxy status from Cloudflare API when proxied is "true"
  if [ "${proxied}" == "true" ]; then
    dns_record_info=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$record" \
      -H "Authorization: Bearer $cloudflare_zone_api_token" \
      -H "Content-Type: application/json")
    if [[ ${dns_record_info} == *"\"success\":false"* ]]; then
      echo ${dns_record_info}
      echo "Error! Can't get dns record info from Cloudflare API"
      exit 0
    fi
    is_proxed=$(echo ${dns_record_info} | grep -o '"proxied":[^,]*' | grep -o '[^:]*$')
    dns_record_ip=$(echo ${dns_record_info} | grep -o '"content":"[^"]*' | cut -d'"' -f 4)
  fi

  ### Check if ip or proxy have changed
  if [ ${dns_record_ip} == ${ip} ] && [ ${is_proxed} == ${proxied} ]; then
    echo "==> DNS record IP of ${record} is ${dns_record_ip}", no changes needed.
    continue
  fi

  echo "==> DNS record of ${record} is: ${dns_record_ip}. Trying to update..."

  ### Get the dns record information from Cloudflare API
  cloudflare_record_info=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$record" \
    -H "Authorization: Bearer $cloudflare_zone_api_token" \
    -H "Content-Type: application/json")
  if [[ ${cloudflare_record_info} == *"\"success\":false"* ]]; then
    echo ${cloudflare_record_info}
    echo "Error! Can't get ${record} record information from Cloudflare API"
    exit 0
  fi

  ### Get the dns record id from response
  cloudflare_dns_record_id=$(echo ${cloudflare_record_info} | grep -o '"id":"[^"]*' | cut -d'"' -f4)

  ### Push new dns record information to Cloudflare API
  update_dns_record=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$cloudflare_dns_record_id" \
    -H "Authorization: Bearer $cloudflare_zone_api_token" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$record\",\"content\":\"$ip\",\"ttl\":$ttl,\"proxied\":$proxied}")
  if [[ ${update_dns_record} == *"\"success\":false"* ]]; then
    echo ${update_dns_record}
    echo "Error! Update failed"
    exit 0
  fi

  echo "==> Success!"
  echo "==> $record DNS Record updated to: $ip, ttl: $ttl, proxied: $proxied"
done
