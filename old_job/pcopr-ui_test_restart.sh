cd /root/app/intellect-static/pc-opr
svn update
npm install
npm run build
rm -rf /root/static/qqcharger/pcopr
cp -r /root/app/intellect-static/pc-opr/dist  /root/static/qqcharger/pcopr
cd /root/static/qqcharger
rm -f pcopr.tar.gz
tar -zcvf pcopr.tar.gz ./pcopr/
