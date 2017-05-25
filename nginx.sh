#/bin/bash

NGINX_VER=nginx-1.12.0
CONF_FILE=rtmp.nginx.conf
ROOT_PWD=`pwd`
BINARY=`which nginx > /dev/null 2>&1`

if [ ! -x $BINARY ]
then
	echo "NGINX not currently installed"
elif [ -x $BINARY ]
then
	echo "NGINX is already installed"
	INSTALL_VER=`nginx -v 2>&1 | awk '{print $3}'`
	echo "Installed version: $INSTALL_VER"
	echo "Attempt to install again over existing version?"
	read -n 1 -p "Enter [y/n]: " RESPONSE
	case $RESPONSE in
	y|Y  ) echo ""; :;;
	n|N  ) echo ""; exit 1;;
	* ) echo ""; echo "ERROR: Invalid selection, aborting operation!"; exit 1;;
	esac
	echo "Stopping any running instances of NGINX"
	sudo systemctl nginx stop > /dev/null 2>&1
	sudo pkill nginx > /dev/null 2>&1; sleep 2
	sudo pkill -9 nginx > /dev/null 2>&1
fi

echo "Installing native NGINX package"
sudo yum install -y nginx gcc make libaio-devel pcre-devel openssl-devel expat-devel zlib-devel libxslt-devel libxslt-devel gd-devel GeoIP-devel gperftools-devel perl-ExtUtils-Embed

echo "Setting up directory/folder structure"
sudo mkdir -p /home/nginx
sudo chown nginx:nginx /home/nginx
sudo mkdir -p /var/www/html/
sudo chown -R nginx:nginx /var/www/html/

if [ ! -d $NGINX_VER ] && [ ! -f $NGINX_VER.tar ] && [ ! -f $NGINX_VER.tar.gz ]
then
	# Get NGINX stable source distribution
	echo "Retrieving NGINX source code"
	wget http://nginx.org/download/$NGINX_VER.tar.gz
	gzip -d -f $NGINX_VER.tar.gz
	tar -xf $NGINX_VER.tar

elif [ -d $NGINX_VER ]
then
	echo "NGINX source code already present on system"

elif [ -f $NGINX_VER.tar ]
then
        tar -xf $NGINX_VER.tar

elif [ -f $NGINX_VER.tar.gz ]
then
	gzip -d -f $NGINX_VER.tar.gz
	tar -xf $NGINX_VER.tar
fi

# Get NGINX Auth Digest module source code
# Note: There are several different implementations!
git clone https://github.com/atomx/nginx-http-auth-digest.git
# Get NGINX Additional WebDav Support
git clone https://github.com/arut/nginx-dav-ext-module.git
# Get NGINX RTMP module source code
git clone https://github.com/arut/nginx-rtmp-module.git

# Compile NGINX agaist external modules
#
cd $NGINX_VER; sudo ./configure --add-module=../nginx-http-auth-digest --add-module=../nginx-dav-ext-module --add-module=../nginx-rtmp-module --prefix=/usr/share/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-client-body-temp-path=/var/lib/nginx/tmp/client_body --http-proxy-temp-path=/var/lib/nginx/tmp/proxy --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi --http-scgi-temp-path=/var/lib/nginx/tmp/scgi --pid-path=/run/nginx.pid --lock-path=/run/lock/subsys/nginx --user=nginx --group=nginx --with-file-aio --with-ipv6 --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-http_addition_module --with-http_xslt_module=dynamic --with-http_image_filter_module=dynamic --with-http_geoip_module=dynamic --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_slice_module --with-http_stub_status_module --with-http_perl_module=dynamic --with-mail=dynamic --with-mail_ssl_module --with-pcre --with-pcre-jit --with-stream=dynamic --with-stream_ssl_module --with-google_perftools_module --with-debug --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic' --with-ld-opt='-Wl,-z,relro -Wl,-E'

echo "Compiling NGINX with RTMP from source"
if (sudo make)
then
	echo "Installing NGINX binaries"
	sudo make install
	cd ..
else
	cd ..
	echo "Compilation of NGINX failed"; exit 1
fi

echo "Copying configuration files, setting up web root folder"
sudo cp -r /usr/share/nginx/html/* /var/www/html
sudo cp nginx-rtmp-module/stat.xsl /var/www/html/stat.xsl
sudo mkdir -p /var/cache/nginx/client_temp /var/www/html/dash
sudo chown -R nginx:nginx /var/cache/nginx/ /var/www/html/dash
sudo cp -R nginx/* /etc/nginx

echo "Installing FFMPEG through dextop REPO"
sudo rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro
sudo rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm
sudo yum -y install ffmpeg

echo "Enabling native NGINX to start at boot"
sudo systemctl enable nginx

echo "Starting NGINX..."
if (sudo systemctl start nginx)
then
	echo "NGINX startup completed successfully"; exit 0
fi
