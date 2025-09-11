cd /root/app/intellect-static/intellect-platform/platform-qqcharger/pc-cust
svn update
npm install
npm run build--ls_prod
rm -rf /root/static/qqcharger/pccust
cp -r /root/app/intellect-static/intellect-platform/platform-qqcharger/pc-cust/dist  /root/static/qqcharger/pccust
cd /root/static/qqcharger
rm -f pccust.tar.gz
tar -zcvf pccust.tar.gz ./pccust/

