#!/bin/bash
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -L "$0" ]; then
  script=$(readlink -f "$0")
  script_dir=$(dirname "$script")
fi
cd $script_dir

if ! command -v cloudflared &>/dev/null; then
    # install cloudflare cli
    echo "${Green}********Installing cloudflare cli********${Color_Off}"
    rm -f cloudflared-linux-amd64.deb
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && dpkg -i cloudflared-linux-amd64.deb && rm -f cloudflared-linux-amd64.deb
fi

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

if [ ! -f "domain_list" ]; then
  echo "ERROR: domain_list file is not exist"
  exit 1
fi

source script.env

CONFIG_FILE=/root/.cloudflared/config.yml

rm -f $CONFIG_FILE
rm -f /etc/cloudflared/config.yml

# create cloudflare tunnel config file
mkdir -p /root/.cloudflared /etc/cloudflared
cp cert.pem /root/.cloudflared/cert.pem 
cp cert.pem /etc/cloudflared/cert.pem

CF_TUNNEL_NAME="${USERNAME}-dev-tunnel-${DEV_SITE}"
if [[ $(cloudflared tunnel list | grep -w "$CF_TUNNEL_NAME") == "" ]]; then
  echo "INFO: Creating cloudflare tunnel..."
  cloudflared tunnel create $CF_TUNNEL_NAME  
fi

CF_TUNNEL_ID=$(cloudflared tunnel list | grep -w "$CF_TUNNEL_NAME" | awk '{print $1}')

if [ -z "$CF_TUNNEL_ID" ]; then
  echo "ERROR: Failed to create cloudflare tunnel"
  exit 1
fi

if [ ! -f "/root/.cloudflared/$CF_TUNNEL_ID.json" ]; then
  # check if overwrite is true
  if [ "$OVERWRITE" == "true" ]; then
    echo "INFO: Overwriting cloudflare tunnel credentials..."
    cloudflared tunnel delete $CF_TUNNEL_ID
    cloudflared tunnel create $CF_TUNNEL_NAME
    CF_TUNNEL_ID=$(cloudflared tunnel list | grep -w "$CF_TUNNEL_NAME" | awk '{print $1}')
  else
    echo "ERROR: this cloudflare tunnel is connected to other device, please change DEV_SITE ENV in script.env and run:
    sudo bash setup_cloudflare_tunnel.sh"
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
  if [[ -z "$line" || "$line" =~ ^\s*# ]]; then
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
  echo "INFO: not found cloudflared, installing cloudflared service..."
  (
    rm -f /etc/cloudflared/config.yml
    cd /etc/systemd/system/
    rm -f cloudflared*
    sudo cloudflared service install
    sudo systemctl enable cloudflared
    sudo systemctl start cloudflared
  )
fi