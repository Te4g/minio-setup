read -p "Domain name or IP adress: " DOMAIN_NAME
read -p "Email address for Certbot: " EMAIL_ADDRESS
read -p "Server reference (ex: s1, s2 ...): " SERVER_REFERENCE
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
MINIO_OPTS='-C /etc/minio --address $SERVER_REFERENCE.$DOMAIN_NAME:$MINIO_PORT --console-address :$MINIO_CONSOLE_PORT'
EOF"
sudo apt update
curl -O https://dl.min.io/server/minio/release/linux-amd64/minio
curl -O https://raw.githubusercontent.com/minio/minio-service/master/linux-systemd/minio.service
sudo chmod +x minio
sudo mv minio /usr/local/bin
sudo useradd -r minio-user -s /sbin/nologin
sudo chown minio-user:minio-user /usr/local/bin/minio
sudo mkdir -p /data
sudo chown minio-user:minio-user /data
sudo mkdir -p /etc/minio
sudo chown minio-user:minio-user /etc/minio
sudo cp ./minio.config /etc/default/minio
sudo cp ./minio.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable minio
sudo systemctl start minio
## < Minio related ###

## > HTTPS related ###
sudo apt install software-properties-common -y
sudo add-apt-repository universe
sudo apt update
sudo apt install certbot -y
sudo certbot certonly --standalone -d "$SERVER_REFERENCE"."$DOMAIN_NAME" --non-interactive --staple-ocsp --agree-tos -m "$EMAIL_ADDRESS"
sudo cp /etc/letsencrypt/live/"$SERVER_REFERENCE"."$DOMAIN_NAME"/privkey.pem /etc/minio/certs/private.key
sudo cp /etc/letsencrypt/live/"$SERVER_REFERENCE"."$DOMAIN_NAME"/fullchain.pem /etc/minio/certs/public.crt
sudo chown minio-user:minio-user /etc/minio/certs/private.key
sudo chown minio-user:minio-user /etc/minio/certs/public.crt
sudo systemctl restart minio
## < HTTPS related ###

## > Certbot post-renew hook
sudo bash -c "cat <<EOF> /etc/letsencrypt/renewal-hooks/post/postRenew.sh
sudo cp /etc/letsencrypt/live/$SERVER_REFERENCE.$DOMAIN_NAME/privkey.pem /etc/minio/certs/private.key
sudo cp /etc/letsencrypt/live/$SERVER_REFERENCE.$DOMAIN_NAME/fullchain.pem /etc/minio/certs/public.crt
sudo chown minio-user:minio-user /etc/minio/certs/private.key
sudo chown minio-user:minio-user /etc/minio/certs/public.crt
sudo systemctl restart minio
EOF"
sudo chmod +x /etc/letsencrypt/renewal-hooks/post/postRenew.sh
## < Certbot post-renew hook

printf "\nInstallation completed, you should access Minio console here: \nhttps://%s.%s:%s\nLogin: %s\nPassword: %s\n" \
"$SERVER_REFERENCE" "$DOMAIN_NAME" "$MINIO_CONSOLE_PORT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
