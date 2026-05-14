#!/bin/bash
TARGET_IP=__AGENT_IP__
USER=testuser
PASS=__TESTUSER_PASS__
LOGFILE=/var/log/legit_ssh.log

echo "Connexion légitime lancée à $(date)" >> $LOGFILE
sshpass -p "$PASS" /usr/bin/ssh $USER@$TARGET_IP -p 22 \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  "echo 'Connexion réussie'" >> $LOGFILE 2>&1
