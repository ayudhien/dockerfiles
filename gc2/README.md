First start PostGreSQL and Elasticsearch:

    sudo docker run --name gc2_postgres -d mapcentia/gc2 sudo -u postgres /usr/lib/postgresql/9.3/bin/postgres -D /var/lib/postgresql/9.3/main -c config_file=/etc/postgresql/9.3/main/postgresql.conf -D FOREGROUND

And:

    sudo docker run --name gc2_elasticsearch -d -t mapcentia/gc2 /usr/share/elasticsearch/bin/elasticsearch -D FOREGROUND

The start the HTTP server with container links:

    sudo docker run --name gc2_apache2 --link gc2_elasticsearch:gc2_elasticsearch --link gc2_postgres:gc2_postgres -p 80:80 -d -t mapcentia/gc2 /root/run-apache.sh -D FOREGROUND

Enjoy!

![MapCentia](http://www.mapcentia.com/images/__od/863/mapcentialogo.png)

http://www.mapcentia.com/en/geocloud/