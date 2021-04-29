#!/bin/bash

set -euxo pipefail

export AWS_DEFAULT_REGION=${aws_default_region}
export CONCOURSE_USER=${concourse_username}
export CONCOURSE_PASSWORD=${concourse_password}

mkdir -p /etc/concourse

# Obtain keys from AWS Secrets Manager
aws secretsmanager get-secret-value --secret-id ${session_signing_key_private_secret_arn} --query SecretBinary --output text | base64 -d > /etc/concourse/session_signing_key
aws secretsmanager get-secret-value --secret-id ${session_signing_key_public_secret_arn} --query SecretBinary --output text | base64 -d > /etc/concourse/session_signing_key.pub
aws secretsmanager get-secret-value --secret-id ${tsa_host_key_private_secret_arn} --query SecretBinary --output text | base64 -d > /etc/concourse/tsa_host_key
aws secretsmanager get-secret-value --secret-id ${tsa_host_key_public_secret_arn} --query SecretBinary --output text | base64 -d > /etc/concourse/tsa_host_key.pub
aws secretsmanager get-secret-value --secret-id ${worker_key_private_secret_arn} --query SecretBinary --output text | base64 -d > /etc/concourse/worker_key
aws secretsmanager get-secret-value --secret-id ${worker_key_public_secret_arn} --query SecretBinary --output text | base64 -d > /etc/concourse/worker_key.pub
cp /etc/concourse/worker_key.pub /etc/concourse/authorized_worker_keys


wget -q https://github.com/concourse/concourse/releases/download/v${concourse_version}/concourse-${concourse_version}-linux-amd64.tgz
tar -zxf concourse-*.tgz -C /usr/local

cat >> /etc/profile.d/concourse.sh << \EOF
  PATH="/usr/local/concourse/bin:$PATH"
EOF

source /etc/profile.d/concourse.sh

cat <<EOF >> /etc/systemd/system/concourse-web.env
CONCOURSE_POSTGRES_PASSWORD=${concourse_db_password}
CONCOURSE_POSTGRES_USER=${concourse_db_username}
CONCOURSE_USER=${concourse_username}
CONCOURSE_PASSWORD=${concourse_password}
CONCOURSE_ADD_LOCAL_USER=$CONCOURSE_USER:$CONCOURSE_PASSWORD
CONCOURSE_MAIN_TEAM_LOCAL_USER=$CONCOURSE_USER
EOF

if [[ "$(rpm -qf /sbin/init)" == upstart* ]];
then
    initctl start concourse-web
else
    systemctl enable concourse-web.service
    systemctl start concourse-web.service
fi

sleep 20
