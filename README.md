# NGINX server for MPEG-DASH hosting and content caching

This source code repository contains the shell scripts necessary to build a server running NGINX. The software will be configured for WebDAV write access, to allow for the hosting and distribution of MPEG-DASH video streams. In conjunctions with some complmentary scripts, it can also be used to cache video streams hosted at external sites/locations, such as MPEG-DASH streams distributed by Akamai. The repo is marked public, which means it is possible to anonymously browse the code and clone the repository.

* Installs the NGINX web server with a number of external modules compiled in
* Configures NGINX to serve web content from HTTP/80
* Enables WebDAV write access to a folder under the web root, /dash
* Configures NGINX to listen on port tcp/3129 and act as a transparent cache
* Configures NGINX to act as an RTMP server/endpoint 
* Can potentially be used for transcoding live streams between formats (not functional yet)

Clone the repo using git and then run the installation script:

    $ sudo -i
    # yum -y install git
    # git clone https://bitbucket.dev.int.nokia.com/scm/toc/nginx-native.git
    # cd nginx-native
    # ./nginx.sh

### Using the server

Once the install has completed, you should have a running NGINX server:

    [nokia@nuc-router ~]$ ps -ef | grep nginx
    root      1320     1  0 15:19 ?        00:00:00 nginx: master process /usr/sbinnginx
    nginx     1321  1320  0 15:19 ?        00:00:00 nginx: worker process
    nginx     1322  1320  0 15:19 ?        00:00:00 nginx: cache manager process
    nginx     1323  1320  0 15:19 ?        00:00:00 nginx: cache loader process

The server will be listening on three separate TCP ports:

    [nokia@nuc-router ~]$ netstat -an
    Active Internet connections (servers and established)
    Proto Recv-Q Send-Q Local Address           Foreign Address         State      
    tcp        0      0 0.0.0.0:1935            0.0.0.0:*               LISTEN     
    tcp6       0      0 :::80                   :::*                    LISTEN     
    tcp6       0      0 :::3129                 :::*                    LISTEN     

The roles of these ports are described in the table below:

Port     | Description
---------| -----------
tcp/80	 | Web server with WebDAV enabled for /dash location
tcp/3129 | Web server for transparent stream caching
tcp/1935 | RTMP server/endpoint for stream transcoding

With the server running, you can test the publishing of files by using the following command:

    user@MacBook:~/nginx-native$ echo "Testing" > test.txt
    user@MacBook:~/nginx-native$ curl -T test.txt http://192.168.96.1/dash/test.txt

This will upload a file called test.txt to the server and deposit it in the /dash folder. You can verify that it has arrived by navigating to /var/www/html/dash and looking for it:

    [root@nuc-router dash]# cd /var/www/html/dash
    [root@nuc-router dash]# pwd
    /var/www/html/dash
    [root@nuc-router dash]# ls
    test.txt
    [root@nuc-router dash]# cat test.txt 
    Testing

