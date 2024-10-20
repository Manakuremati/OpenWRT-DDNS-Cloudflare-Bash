#!/usr/bin/env bash

###  Create .update-cloudflare-dns.log file of the last run for debug
parent_path="$(dirname "${BASH_SOURCE[0]}")"

### Write last run of STDOUT & STDERR as log file and prints to screen
echo "$(date "+%Y-%m-%d %H:%M:%S")"
logger -p notice "$(date "+%Y-%m-%d %H:%M:%S")"

### Validate if config-file exists

if [[ -z "$1" ]]; then
  if ! source "${parent_path}"/update-cloudflare-dns.conf; then
    echo "Error! Missing configuration file update-cloudflare-dns.conf or invalid syntax!"
	logger -p notice "Error! Missing configuration file update-cloudflare-dns.conf or invalid syntax!"
    exit 0
  fi
else
  if ! source "${parent_path}"/"$1"; then
    echo "Error! Missing configuration file "$1" or invalid syntax!"
	logger -p notice "Error! Missing configuration file "$1" or invalid syntax!"
    exit 0
  fi
fi

### Check validity of "ttl" parameter
if [ "${ttl}" -lt 60 ] || [ "${ttl}" -gt 86400 ] && [ "${ttl}" -ne 1 ]; then
  echo "Error! ttl out of range (60-86400) or not set to 1"
  logger -p notice "Error! ttl out of range (60-86400) or not set to 1"
  exit
fi

### Check validity of "proxied" parameter
if [ "${proxied}" != "false" ] && [ "${proxied}" != "true" ]; then
  echo 'Error! Incorrect "proxied" parameter, choose "true" or "false"'
  logger -p notice 'Error! Incorrect "proxied" parameter, choose "true" or "false"'
  exit 0
fi

### Valid IPv4 Regex
REIP='^((25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])\.){3}(25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])$'

### Get internal IP
ip=$(ifstatus wan |  jsonfilter -e '@["ipv4-address"][0].address')
  if [ -z "$ip" ]; then
    echo "Error! Can't get ip"
	logger -p notice "Error! Can't get ip"
    exit 0
  fi
  if ! [[ "$ip" =~ $REIP ]]; then
    echo "Error! IP Address returned was invalid!"
	logger -p notice "Error! IP Address returned was invalid!"
    exit 0
  fi
echo "WAN IP is: $ip"
logger -p notice "WAN IP is: $ip"

### Build coma separated array fron dns_record parameter to update multiple A records
IFS=',' read -d '' -ra dns_records <<<"$dns_record,"
unset 'dns_records[${#dns_records[@]}-1]'
declare dns_records

for record in "${dns_records[@]}"; do

  ### Get the dns record id and current proxy status from Cloudflare API
    dns_record_info=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$record" \
      -H "Authorization: Bearer $cloudflare_zone_api_token" \
      -H "Content-Type: application/json")
    if [[ ${dns_record_info} == *"\"success\":false"* ]]; then
      echo "${dns_record_info}"
	  logger -p notice "${dns_record_info}"
      echo "Error! Cannot get dns record info from Cloudflare API"
	  logger -p notice "Error! Cannot get dns record info from Cloudflare API"
      exit 0
    fi
    cloud_proxied=$(echo "${dns_record_info}" | grep -o '"proxied":[^,]*' | grep -o '[^:]*$')
    cloud_ip=$(echo "${dns_record_info}" | grep -o '"content":"[^"]*' | cut -d'"' -f 4)
    cloud_id=$(echo "${dns_record_info}" | grep -o '"id":"[^"]*' | cut -d'"' -f4)

  ### Check if ip or proxy have changed
  if [ ${cloud_ip} == "${ip}" ] && [ "${cloud_proxied}" == "${proxied}" ]; then
    echo "DNS record IP of ${record} is ${cloud_ip} , no changes needed."
	logger -p notice "DNS record IP of ${record} is ${cloud_ip} , no changes needed."
    continue
  fi

  echo "DNS record of ${record} is: ${cloud_ip}. Trying to update..."
  logger -p notice "DNS record of ${record} is: ${cloud_ip}. Trying to update..."

  ### Push new dns record information to Cloudflare API
  update_dns_record=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$cloud_id" \
    -H "Authorization: Bearer $cloudflare_zone_api_token" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$record\",\"content\":\"$ip\",\"ttl\":$ttl,\"proxied\":$proxied}")
  if [[ ${update_dns_record} == *"\"success\":false"* ]]; then
    echo "${update_dns_record}"
	logger -p notice "${update_dns_record}"
    echo "Error! Update failed"
	logger -p notice "Error! Update failed"
    exit 0
  fi

  echo "Success $record DNS Record updated to: $ip, ttl: $ttl, proxied: $proxied"
  logger -p notice "Success $record DNS Record updated to: $ip, ttl: $ttl, proxied: $proxied"
done
