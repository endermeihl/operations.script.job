#!/bin/bash
cd /root/app/intellect-static/pc-achievements/
svn update
npm install
npm run build
rm -rf /root/static/qqcharger/pcachievements
cp -r /root/app/intellect-static/pc-achievements/dist  /root/static/qqcharger/pcachievements
cd /root/static/qqcharger
rm -f pcachievements.tar.gz
tar -zcvf pcachievements.tar.gz ./pcachievements/
