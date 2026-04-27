#!/bin/bash
TARGET_IP=10.0.30.25
USER=testuser
PASS=123456
LOGFILE=/var/log/legit_ssh.log

echo "Connexion légitime lancée à $(date)" >> $LOGFILE

sshpass -p "$PASS" /usr/bin/ssh $USER@$TARGET_IP -p 22 \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  "echo 'Connexion réussie depuis Wazuh'" >> $LOGFILE 2>&1
