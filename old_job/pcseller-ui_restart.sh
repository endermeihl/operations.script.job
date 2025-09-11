cd /root/app/intellect-static/intellect-platform/platform-qqcharger/pc-seller
svn update
npm install
npm run build
rm -rf /root/static/qqcharger/pcseller
cp -r /root/app/intellect-static/intellect-platform/platform-qqcharger/pc-seller/dist  /root/static/qqcharger/pcseller
cd /root/static/qqcharger
rm -f pcseller.tar.gz
tar -zcvf pcseller.tar.gz ./pcseller/
