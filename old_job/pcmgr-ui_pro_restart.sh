cd /root/app/intellect-static/intellect-platform/platform-qqcharger/pc-mgr
svn update
npm install
npm run build--prod
rm -rf /root/static/qqcharger/pcmgr
cp -r /root/app/intellect-static/intellect-platform/platform-qqcharger/pc-mgr/dist  /root/static/qqcharger/pcmgr
cd /root/static/qqcharger
rm -f pcmgr.tar.gz
tar -zcvf pcmgr.tar.gz ./pcmgr/
