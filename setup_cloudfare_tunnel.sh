#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPTDIR

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -o|--overwrite)
      OVERWRITE=true
      shift
      ;;
    *)
      echo "ERROR: Unknown option: $key"
      exit 1
      ;;
  esac
done

if [ ! -f "script.env" ]; then
  echo "ERROR: script.env file is not exist"
  exit 1
fi

source script.env
CONFIG_FILE=/root/.cloudflared/config.yml

cp domain_list_template domain_list

sed -i "s/<n>/$DEV_SITE/g" domain_list
sed -i "s/<zonename>/$CF_ZONE_NAME/g" domain_list

rm -f $CONFIG_FILE
rm -f /etc/cloudflared/config.yml

# create cloudflare tunnel config file
mkdir -p /root/.cloudflared /etc/cloudflared
cp cert.pem /root/.cloudflared/cert.pem 
cp cert.pem /etc/cloudflared/cert.pem

if [[ $(cloudflared tunnel list | grep $CF_TUNNEL_NAME) == "" ]]; then
  echo "INFO: Creating cloudflare tunnel..."
  cloudflared tunnel create $USERNAME-$CF_TUNNEL_NAME  
fi
CF_TUNNEL_ID=$(cloudflared tunnel list | grep $CF_TUNNEL_NAME | awk '{print $1}')

if [ ! -f "/root/.cloudflared/$CF_TUNNEL_ID.json" ]; then
  # check if overwrite is true
  if [ "$OVERWRITE" == "true" ]; then
    echo "INFO: Overwriting cloudflare tunnel credentials..."
    cloudflared tunnel delete $CF_TUNNEL_ID
    cloudflared tunnel create $USERNAME-$CF_TUNNEL_NAME
  else
    echo "ERROR: this cloudflare tunnel is connected to other device, please change DEV_SITE ENV in script.env and run:
    sudo bash setup_cloudfare_tunnel.sh"
    exit 1
  fi
fi

# Create config file header
cat <<EOF > $CONFIG_FILE
tunnel: $CF_TUNNEL_ID
credentials-file: /root/.cloudflared/$CF_TUNNEL_ID.json

ingress:
EOF

while IFS=: read -r line || [[ -n "$line" ]]; do
  if [[ -z "$line" ]]; then
    continue
  fi
  # Extract record and port
  record=$(echo "$line" | awk -F':' '{print $1}')
  port=$(echo "$line" | awk -F':' '{print $2}')
  # route cloudflare dns
  cloudflared tunnel route dns --overwrite-dns $CF_TUNNEL_ID $record
  # Add record to config file
  cat <<EOF >> $CONFIG_FILE
  - hostname: $record
    service: http://localhost:$port
EOF
done < "domain_list"

cat <<EOF >> $CONFIG_FILE
  - service: http_status:404
EOF

echo "INFO: Config file written to $CONFIG_FILE"

# check if /etc/cloudflared/config.yml exist and cloudflared.service is installed
if [ "$(systemctl is-enabled cloudflared.service)" == "enabled" ]; then
  echo "INFO: updating cloudflared service..."
  cp $CONFIG_FILE /etc/cloudflared/config.yml
  sudo systemctl restart cloudflared
else
  echo "INFO: installing cloudflared service..."
  rm -f /etc/cloudflared/config.yml
  rm -f cloudflared-update.service cloudflared.service
  sudo cloudflared service install
  sudo systemctl enable cloudflared
  sudo systemctl start cloudflared
fi