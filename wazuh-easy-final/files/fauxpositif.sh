#!/bin/bash
TARGET_IP=__AGENT_IP__
USER=testuser
LOGFILE=/var/log/fauxpositif.log

echo "Faux positif lancé à $(date)" >> $LOGFILE
# 2 tentatives échouées (mauvais mot de passe)
sshpass -p "wrongpass" ssh $USER@$TARGET_IP -p 22 \
  -o StrictHostKeyChecking=no -o ConnectTimeout=5 exit >> $LOGFILE 2>&1
sshpass -p "wrongpass" ssh $USER@$TARGET_IP -p 22 \
  -o StrictHostKeyChecking=no -o ConnectTimeout=5 exit >> $LOGFILE 2>&1
# 3ème tentative réussie (bon mot de passe)
sshpass -p "__TESTUSER_PASS__" ssh $USER@$TARGET_IP -p 22 \
  -o StrictHostKeyChecking=no -o ConnectTimeout=5 exit >> $LOGFILE 2>&1
