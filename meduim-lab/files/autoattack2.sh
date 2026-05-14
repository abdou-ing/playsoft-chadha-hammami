#!/bin/bash
TARGET_IP=10.0.30.25
USER=ghostuser   # utilisateur inexistant
LOGFILE=/var/log/autoattack2.log

echo "Autoattack2 lancé à $(date)" >> $LOGFILE

for i in {1..8}; do
  echo "Tentative $i vers $TARGET_IP avec $USER" >> $LOGFILE
  /usr/bin/ssh $USER@$TARGET_IP -p 22 \
    -o PreferredAuthentications=password \
    -o PubkeyAuthentication=no \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=5 \
    -o BatchMode=yes \
    exit >> $LOGFILE 2>&1
done

exit 0
