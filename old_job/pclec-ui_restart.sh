cd /root/app/intellect-static/intellect-platform/platform-qqcharger/pc-lec
svn update
npm install
npm run build
rm -rf /root/static/qqcharger/pclec
cp -r /root/app/intellect-static/intellect-platform/platform-qqcharger/pc-lec/dist  /root/static/qqcharger/pclec
cd /root/static/qqcharger
rm -f pclec.tar.gz
tar -zcvf pclec.tar.gz ./pclec/
