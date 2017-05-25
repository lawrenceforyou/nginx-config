# NGINX Server Configuration Script

# For MPEG-DASH hosting, stream caching, transcoding

This source code repository contains the shell scripts necessary to build a server running NGINX. The software will be configured for WebDAV write access, to allow for the hosting and distribution of MPEG-DASH video streams. In conjunction with some complementary scripts, it can also be used to cache video streams hosted at external sites/locations, such as MPEG-DASH streams distributed by Akamai and their CDN network. NGINX can also accept an RTMP stream and convert/transcode it to an MPEG-DASH stream. Most of the functionality described here is still under heavy testing and development.

* Installs the NGINX web server with a number of external modules compiled in
* Configures NGINX to serve web content from HTTP/80
* Enables WebDAV write access to a folder under the web root, /dash and /dash-auth
* Configures NGINX to listen on port tcp/3129 and acts as a transparent cache on that port
* Configures NGINX to act as an RTMP server/endpoint and enables stream transcoding to MPEG-DASH

Clone the repo using git and then run the installation script:

    $ sudo -i
    # yum -y install git
    # git clone https://github.com/mwatkins-nt/nginx-config.git
    # cd nginx-config
    # ./nginx.sh

### Using the server

Once the install has completed, you should have a running NGINX server:

    [nokia@nuc-router ~]$ ps -ef | grep nginx
    root     10710     1  0 11:32 ?        00:00:00 nginx: master process /usr/sbin/nginx
    nginx    10711 10710  0 11:32 ?        00:00:01 nginx: worker process
    nginx    10712 10710  0 11:32 ?        00:00:00 nginx: cache manager process

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

With the server running, you can test the publishing of files through WebDAV by using the following command:

    $ echo "Testing" > test.txt
    $ curl -T test.txt http://127.0.0.1/dash/test.txt

(the above works locally on the server, you need to substitute the LAN IP address if performing the test over the network)

This will upload a file called test.txt to the server and deposit it in the /dash folder. You can verify that it has arrived by navigating to /var/www/html/dash and looking for it:

    $ cd /var/www/html/dash
    $ pwd
    /var/www/html/dash
    $ ls
    test.txt
    $ cat test.txt 
    Testing

You can also use a password protected publishing process by sending files to /dash-auth instead of /dash. Due to limitations in NGINX, only basic authentication (not Digest) is permitted at this time. Publishing to this location without sending credentials should fail, e.g.

    $ curl -T test.txt http://127.0.0.1/dash-auth/test.txt
    <html>
    <head><title>401 Authorization Required</title></head>
    <body bgcolor="white">
    <center><h1>401 Authorization Required</h1></center>
    <hr><center>nginx/1.12.0</center>
    </body>
    </html>

Then supplying a valid username and password:

    $ curl -u dash:nokia-dash -T test.txt http://127.0.0.1/dash-auth/test.txt
    $ ls /var/www/html/dash-auth/
    test.txt

The credentials protecting the publishing process can be found in the following file:

    $ cat /etc/nginx/passwd.basic 
    # realm=mpeg-dash username=dash password=nokia-dash
    dash:$apr1$0iPqvlao$CzleYcKAczh.VStRqlTTG0

The password can be changed or generated using the utilities htpasswd and htdigest, e.g.

    $ sudo htpasswd -c /etc/nginx/passwd.basic dash
    [sudo] password for nokia: 
    New password: 
    Re-type new password: 
    Adding password for user dash
    $ cat /etc/nginx/passwd.basic
    dash:$apr1$/Ys6kN9N$9Sv038JwtBdcQ/v4I6WBj0

Now we try supplying the wrong password:

    $ curl -u dash:nokia-dash -T test.txt http://127.0.0.1/dash-auth/test.txt
    <html>
    <head><title>401 Authorization Required</title></head>
    <body bgcolor="white">
    <center><h1>401 Authorization Required</h1></center>
    <hr><center>nginx/1.12.0</center>
    </body>
    </html>

You will see the following int he NGINX error log:

    2017/05/25 12:17:38 [error] 10711#0: *211 user "dash": password mismatch, client: ::ffff:127.0.0.1, server: nuc-router, request: "PUT /dash-auth/test.txt HTTP/1.1", host: "127.0.0.1"

Then use the new password:

    $ curl -u dash:testing -T test.txt http://127.0.0.1/dash-auth/test.txt

If the command exits without error, then the file has been uploaded successfully.

The access logs will show something like:

    ::ffff:127.0.0.1 - dash [25/May/2017:12:17:47 +0100] "PUT /dash-auth/test.txt HTTP/1.1" 204 25 "-" "curl/7.29.0"

