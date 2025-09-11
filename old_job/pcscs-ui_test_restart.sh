cd /root/app/intellect-static/intellect-platform/platform-qqcharger/pc-scs
svn update
npm install
npm run build
rm -rf /root/static/qqcharger/pcscs
cp -r /root/app/intellect-static/intellect-platform/platform-qqcharger/pc-scs/dist  /root/static/qqcharger/pcscs
cd /root/static/qqcharger
rm -f pcscs.tar.gz
tar -zcvf pcscs.tar.gz ./pcscs/
