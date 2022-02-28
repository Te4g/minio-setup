read -p "Domain name or IP address: " DOMAIN_NAME
read -p "Server reference (ex: s1, s2 ...): " SERVER_REFERENCE
read -p "Cloudflare API token: " CLOUDFLARE_API_TOKEN
read -e -p "Minio root username: " -i "minio" MINIO_ROOT_USER
read -e -p "Minio root password: " -i "$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)" MINIO_ROOT_PASSWORD
read -e -p "Minio port: " -i "9000" MINIO_PORT
read -e -p "Minio console port: " -i "9999" MINIO_CONSOLE_PORT
read -e -p "Minio volumes: " -i "/data" MINIO_VOLUMES

## > Minio related ###
sudo bash -c "cat <<EOF> minio.config
MINIO_ROOT_USER=$MINIO_ROOT_USER
MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD
MINIO_VOLUMES=$MINIO_VOLUMES
MINIO_OPTS='-C /etc/minio --address :$MINIO_PORT --console-address :$MINIO_CONSOLE_PORT'
MINIO_PROMETHEUS_AUTH_TYPE=public
EOF"
sudo apt update
curl -O https://dl.min.io/server/minio/release/linux-amd64/minio
curl -O https://raw.githubusercontent.com/minio/minio-service/master/linux-systemd/minio.service
sudo chmod +x minio
sudo mv minio /usr/local/bin
sudo useradd -r minio-user -s /sbin/nologin
sudo chown minio-user:minio-user /usr/local/bin/minio
sudo mkdir -p /data /etc/minio
sudo chown minio-user:minio-user /data /etc/minio
sudo mv ./minio.config /etc/default/minio
sudo mv ./minio.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable --now minio
## < Minio related ###

## > Reverse proxy related ###
sudo groupadd --system caddy
sudo useradd --system \
    --gid caddy \
    --create-home \
    --home-dir /var/lib/caddy \
    --shell /usr/sbin/nologin \
    --comment "Caddy web server" \
    caddy
curl -o caddy "https://caddyserver.com/api/download?os=linux&arch=amd64&p=github.com%2Fcaddy-dns%2Fcloudflare"
curl -O "https://raw.githubusercontent.com/caddyserver/dist/master/init/caddy.service"
sudo chmod +x caddy
sudo chown root:root caddy
sudo mv caddy /usr/bin
sudo mv caddy.service /etc/systemd/system
sudo mkdir -p /var/log/caddy /etc/caddy
sudo chown caddy:caddy /var/log/caddy
sudo bash -c "cat <<EOF> Caddyfile
{
        acme_dns cloudflare $CLOUDFLARE_API_TOKEN
}

$SERVER_REFERENCE.$DOMAIN_NAME {
        log {
                output file /var/log/caddy/caddy.log
        }
        handle / {
                respond 404
        }
        reverse_proxy localhost:$MINIO_PORT
}

console.$SERVER_REFERENCE.$DOMAIN_NAME {
        log {
                output file /var/log/caddy/console.log
        }
        reverse_proxy localhost:$MINIO_CONSOLE_PORT
}
EOF"
sudo mv Caddyfile /etc/caddy/Caddyfile
sudo systemctl daemon-reload
sudo systemctl enable --now caddy
## < Reverse proxy related ###

printf "\nInstallation completed, you should access Minio console here: \nhttps://console.%s.%s\nLogin: %s\nPassword: %s\n" \
"$SERVER_REFERENCE" "$DOMAIN_NAME" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
