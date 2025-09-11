cd /root/app/intellect-static/intellect-platform/platform-qqcharger/pc-router
svn update
npm install
npm run build
rm -rf /root/static/qqcharger/pcrouter
cp -r /root/app/intellect-static/intellect-platform/platform-qqcharger/pc-router/dist  /root/static/qqcharger/pcrouter
cd /root/static/qqcharger
rm -f pcrouter.tar.gz
tar -zcvf pcrouter.tar.gz ./pcrouter/
