#!/bin/bash -ev
set +o history

# Template vars populated by Terraform
DNS_IP=${DNS_IP}
CONSUL_DC=${CONSUL_DC}
CONSUL_KEY=${CONSUL_KEY}
CONSUL_USER=${CONSUL_USER}
CONSUL_SERVERS=${CONSUL_SERVERS}

# Wait for cloud-init to finish.
echo "Waiting 180 seconds for cloud-init to complete."
timeout 180 /bin/bash -c \
  'until stat /var/lib/cloud/instance/boot-finished 2>/dev/null; do echo "Waiting ..."; sleep 2; done'

# Variables fetched from EC2 meta-data service
INSTANCE_REGION=$(curl 'http://169.254.169.254/latest/meta-data/placement/availability-zone' | sed 's/.$//')

# Setup the ECS cluster name
echo "ECS_CLUSTER=${ECS_NAME}" >> /etc/ecs/ecs.config

## Setup consul and registrator containers
mkdir -p /etc/consul.d/{bootstrap,server,client,ssl}
for i in cacert.pem consul.pem consul.key
do
    curl -k -s -S -X GET --keepalive-time 60 --connect-timeout 10 --max-time 120 \
	-H 'Content-Type: text/plain' -H 'Connection: keep-alive' -H 'Keep-Alive: 60' \
	-u "$CONSUL_USER" -L https://storage.mydomain.com/share/ssl/$i -o /etc/consul.d/ssl/$i
done

mkdir -p /opt/consul
mkdir -p /etc/consul.d

cat << EOF > /etc/consul.d/consul.json
{
    "server": false,
    "leave_on_terminate": true,
    "rejoin_after_leave": true,
    "recursors": ["$DNS_IP"],
    "data_dir": "/data",
    "encrypt": "$CONSUL_KEY",
    "ca_file": "/etc/consul/ssl/cacert.pem",
    "cert_file": "/etc/consul/ssl/consul.pem",
    "key_file": "/etc/consul/ssl/consul.key",
    "verify_incoming": true,
    "verify_outgoing": true,
    "log_level": "INFO",
    "dns_config": {
      "enable_truncate": true
    },
    "start_join": [$(echo "$CONSUL_SERVERS" | sed ':a;{N;s/\\n/,/};ba' | sed 's/^/"/;s/$/"/;s/,/", "/g')]
}
EOF

docker pull progrium/consul
docker pull gliderlabs/registrator

# Consul client container
docker run -d --restart=always -p 8301:8301 -p 8301:8301/udp \
-p 8400:8400 -p 8500:8500 -p 53:53/udp \
-v /opt/consul:/data -v /var/run/docker.sock:/var/run/docker.sock \
-v /etc/consul.d:/etc/consul \
-h $(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
--name consul-agent progrium/consul \
-advertise $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) \
-dc $CONSUL_DC \
-config-file /etc/consul/consul.json

# Registrator container
docker run -d --restart=always -v /var/run/docker.sock:/tmp/docker.sock \
-h $(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
--name consul-registrator gliderlabs/registrator:latest \
-ip $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) \
consul://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):8500

exit 0