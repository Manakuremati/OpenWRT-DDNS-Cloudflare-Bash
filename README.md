# DDNS Cloudflare Bash Script for OpenWRT

## Info
This Script is a modified version and is made for OpenWRT
Original Script: [https://github.com/fire1ce/DDNS-Cloudflare-Bash.git](https://github.com/fire1ce/DDNS-Cloudflare-Bash)

## Requirements

- curl
- bash
- Cloudflare [api-token](https://dash.cloudflare.com/profile/api-tokens) with ZONE-DNS-EDIT Permissions
- DNS Record must be pre created (api-token should only edit dns records)

### Creating Cloudflare API Token

To create a CloudFlare API token for your DNS zone go to [https://dash.cloudflare.com/profile/api-tokens][cloudflare-api-token-url] and follow these steps:

1. Click Create Token
2. Select Create Custom Token
3. Provide the token a name, for example, `example.com-dns-zone-readonly`
4. Grant the token the following permissions:
   - Zone - DNS - Edit
5. Set the zone resources to:
   - Include - Specific Zone - `example.com`
6. Complete the wizard and use the generated token at the `CLOUDFLARE_API_TOKEN` variable for the container

## Config file

You can use default config file _update-cloudflare-dns.conf_ or pass your own config file as parameter to script.

Place the **config** file in the directory as the **update-cloudflare-dns**

## Config Parameters

| **Option**                | **Example**      | **Description**                                                                                                           |
| ------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------- |
| dns_record                | ddns.example.com | DNS **A** record which will be updated, you can pass multiple **A** records separated by comma                            |
| cloudflare_zone_api_token | ChangeMe         | Cloudflare API Token **KEEP IT PRIVATE!!!!**                                                                              |
| zoneid                    | ChangeMe         | Cloudflare's [Zone ID](https://developers.cloudflare.com/fundamentals/get-started/basic-tasks/find-account-and-zone-ids/) |
| proxied                   | false            | Use Cloudflare proxy on dns record true/false                                                                             |
| ttl                       | 120              | 60-7200 in seconds or 1 for Auto                                                                                         |


## Running The Script

```shell
<path>/.update-cloudflare-dns.sh
```

## Automation With Crontab

You can run the script via crontab

```shell
crontab -e
```

### Examples

Run every minute

```shell
* * * * * /path/to/script/update-cloudflare-dns.sh
```

Run every 2 minutes

```shell
*/2 * * * * /path/to/script/update-cloudflare-dns
```

Run at boot

```shell
@reboot /path/to/script/update-cloudflare-dns
```

Run 1 minute after boot

```shell
@reboot sleep 60 && /path/to/script/update-cloudflare-dns
```

Run at 08:00

```shell
0 8 * * * /path/to/script/update-cloudflare-dns
```

## Logs

This Script will create a log file with **only** the last run information
Log file will be located at the script's location.

Example:

```bash
/path/to/script/update-cloudflare-dns.log
```

## Limitations

- Does not support IPv6


<!-- urls -->
<!-- appendices -->

[cloudflare-api-token-url]: https://dash.cloudflare.com/profile/api-tokens 'Cloudflare API Token'

<!-- end appendices -->
