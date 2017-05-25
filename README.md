# NGINX Server Configuration Script

## MPEG-DASH hosting, stream caching, transcoding

This source code repository contains the shell scripts necessary to build a server running NGINX. The software will be configured for WebDAV write access, to allow for the hosting and distribution of MPEG-DASH video streams. In conjunction with some complementary scripts, it can also be used to cache video streams hosted at external sites/locations, such as MPEG-DASH streams distributed by Akamai and their CDN network. NGINX can also accept an RTMP stream and convert/transcode it to an MPEG-DASH stream.

*Note: most of the functionality described here is still under heavy testing and development*

The script:

* Installs the NGINX web server with a number of external modules compiled in
* Configures NGINX to serve web content from HTTP/80
* Enables WebDAV write access to a folder under the web root, /dash and /dash-auth
* Configures NGINX to listen on port tcp/3129 and acts as a transparent cache on that port
* Configures NGINX to act as an RTMP server and enables stream transcoding from RTMP to MPEG-DASH

### Installing NGINX

Clone the repo (using git) and then run the installation script:

    $ sudo yum -y install git
    $ git clone https://github.com/mwatkins-nt/nginx-config.git
    $ cd nginx-config
    $ sudo ./nginx.sh

### Examining the server

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

### WebDAV Testing

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

You can also use a password to protect the publishing process by sending files to /dash-auth instead of /dash. Due to limitations in NGINX, only basic authentication (not Digest) is permitted at this time. Publishing to this location without sending credentials should fail, e.g.

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

You will see the following in the NGINX error log:

    2017/05/25 12:17:38 [error] 10711#0: *211 user "dash": password mismatch, client: ::ffff:127.0.0.1, server: nuc-router, request: "PUT /dash-auth/test.txt HTTP/1.1", host: "127.0.0.1"

Then use the new password:

    $ curl -u dash:testing -T test.txt http://127.0.0.1/dash-auth/test.txt

If the command exits without error, then the file has been uploaded successfully.

The access logs will show something like:

    ::ffff:127.0.0.1 - dash [25/May/2017:12:17:47 +0100] "PUT /dash-auth/test.txt HTTP/1.1" 204 25 "-" "curl/7.29.0"

With the publishing process protected by a password, you will want to comment out the /dash section of the NGINX web configuration file in order to disable the unprotected folder (which is otherwise writable by anybody).

### Stream Trancoding

You can test stream transcoding by invoking FFMPEG and providing it with a local video file to simulate the publishing of live content:

    $ ffmpeg -re -i samsung_UHD_demo_3Iceland.mp4 -vcodec libx264 -acodec libfaac -f flv rtmp://[server-ip]/dash/test_TB

(substitute the actual IP address of your server in the string above)

This will deliver your video file to the NGINX RTMP module. After a few moments, you should also be able to see transcoded content being exposed through the NGINX web server at the URL:

http://[server-ip]/transcoding/

(substitute the actual IP address of your server in the string above)

The local directory where this content appears is under /tmp, but it can sometimes be hard to find due to the directory structure involved. The commands shown below should show you the generated MPEG-DASH content.

    $ sudo -i
    # ls -l /tmp/*nginx*/tmp/dash/
    total 11068
    -rw-r--r--. 1 nginx nginx   75117 May 25 14:31 test_TB-0.m4a
    -rw-r--r--. 1 nginx nginx 9198520 May 25 14:31 test_TB-0.m4v
    -rw-r--r--. 1 nginx nginx     596 May 25 14:31 test_TB-init.m4a
    -rw-r--r--. 1 nginx nginx     661 May 25 14:31 test_TB-init.m4v
    -rw-r--r--. 1 nginx nginx    2082 May 25 14:31 test_TB.mpd
    -rw-r--r--. 1 nginx nginx    9978 May 25 14:31 test_TB-raw.m4a
    -rw-r--r--. 1 nginx nginx  984737 May 25 14:31 test_TB-raw.m4v

On my system, the transcoded content could be found at:

/tmp/systemd-private-e25d82fccf2948f4ac7d18717e876ad8-nginx.service-qkAQ0R/tmp/dash

If/when you stop the publishing process with ctrl-C, you should see a message similar to the one below in the /var/log/nginx/access.log file:

    10.49.206.54 [25/May/2017:12:39:05 +0100] PUBLISH "dash" "test_TB" "" - 602675 409 "" "FMLE/3.0 (compatible; Lavf56.25" (7s)

That log message shows that seven seconds of content publishing took place. At this point you should be able to take a live video source outputting RTMP and point it to your server using a URL of the form:

rtmp://[server-ip]/dash/[stream-file-name]

Do NOT add the .mpd suffix to the above, that will be added automatically by the transcoding process.
