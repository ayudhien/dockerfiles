#!/bin/bash

#
# Check Docker
#

VERSION=$(docker info | grep 'Server Version')
if [ "$VERSION" = "" ]; then
    echo "Docker is not installed or the you don't have permission to run Docker."
    exit
else
    echo "Docker info: $VERSION"
fi

#
# Set PostGreSQL pwd
#

echo "Password for new GC2 PostGreSQL user? This is only needed the first time you run this script or if the PostGIS or GC2core containers are re-created. "
read CONF
export PG_PW=$CONF

LOCALE=$(locale | grep LANG= | grep -o '[^=]*$')
echo "Locale [$LOCALE]"
read CONF
if [ "$CONF" != "" ]; then
    LOCALE=$CONF
fi

TIMEZONE=$(date +%Z)
echo "Timezone [$TIMEZONE]"
read CONF
if [ "$CONF" != "" ]; then
    TIMEZONE=$CONF
fi

echo "Enabling New Relic APM metrics? Input your New Relic install key. Blank for not enabling APM"
echo "New Relic license key"
read CONF
if [ "$CONF" != "" ]; then
    NR_INSTALL_KEY=$CONF
    echo "Application name"
        read CONF
        if [ "$CONF" != "" ]; then
            NR_APP_NAME=$CONF
        fi
fi

check () {
    flag=0
    if [[ $(docker ps -a --filter="name=$1" | grep $1$) ]]
        then
                echo "Remove existing $1 container [y/N]"
                read CONF
                if [ "$CONF" = "y" ]; then
                        docker rm -f $1
                        return 1
                fi
        else
                return 1
    fi
}

#
# PostGIS
#

#Create a persistence volume for postgis
if [[ $(docker ps -a --filter="name=postgis-data" | grep postgis-data) ]]
        then
                echo "postgis-data already exists. Doing nothing."
        else
                echo "Creating a persistence volume for postgis...."
                docker create --name postgis-data mapcentia/postgis
fi

check postgis
if [[ $? = 1 ]]
        then
                echo "Running the postgis container...."
                docker create \
                        --name postgis \
                        -p 5432:5432 \
                        --volumes-from postgis-data \
                        -e GC2_PASSWORD=$PG_PW \
                        -e LOCALE=$LOCALE \
                        -e TIMEZONE="$TIMEZONE" \
                        -t mapcentia/postgis
fi

#
# Elasticsearch
#

#Create a persistence volume for elasticsearch.
if [[ $(docker ps -a --filter="name=es-data" | grep es-data) ]]
        then
                echo "es-data already exists. Doing nothing."
        else
                echo "Creating a persistence volume for elasticsearch...."
                docker create --name es-data elasticsearch
fi

check elasticsearch
if [[ $? = 1 ]]
        then
                echo "Running the elasticsearch container...."
                docker create \
                        --name elasticsearch \
                        --volumes-from es-data \
                        -e ES_JAVA_OPTS="-Xms512m -Xmx512m" \
                        --ulimit nofile=98304:98304 \
                        -p 9200:9200 \
                        -t elasticsearch
fi

#
# GC2 data
#

if [[ $(docker ps -a --filter="name=gc2-data" | grep gc2-data) ]]
        then
                echo "gc2-data already exists. Doing nothing."
        else
                echo "Create Apache, PHP5-fpm and GC2 config files for GC2 on host [y/N]"
                read CONF
                if [ "$CONF" = "y" ]; then
                        docker run \
                                --rm -i \
                                -v $PWD/apache2:/tmp mapcentia/gc2core cp /etc/apache2/sites-enabled /tmp -R

                        docker run \
                                --rm -i \
                                -v $PWD/apache2:/tmp mapcentia/gc2core cp /etc/apache2/ssl /tmp -R

                        docker run \
                                --rm -i \
                                -v $PWD/:/tmp mapcentia/gc2core cp /etc/php5/fpm /tmp -R

                        docker run \
                                --rm -i \
                                -v $PWD/gc2:/tmp mapcentia/gc2core cp /var/www/geocloud2/app/conf /tmp -R
                fi
                #Create a persistence volume for GC2. Busybox based.
                echo "Creating a persistence volume for gc2...."
                docker create --name gc2-data \
                        -v /etc/letsencrypt \
                        -v /var/www/geocloud2/app/tmp \
                        -v /var/www/geocloud2/app/wms/files \
                        -v /var/www/geocloud2/app/wms/mapcache \
                        -v /var/www/geocloud2/app/wms/mapfiles \
                        -v /var/www/geocloud2/app/wms/qgsfiles \
                        busybox
fi


#
# GC2 core
#

check gc2core
if [[ $? = 1 ]]
        then
                echo "Running the GC2 container...."
                docker create \
                        --name gc2core \
                        --privileged \
                        --link postgis:postgis \
                        --link elasticsearch:elasticsearch \
                        --volumes-from gc2-data \
                        -v $PWD/apache2/ssl:/etc/apache2/ssl \
                        -v $PWD/apache2/sites-enabled:/etc/apache2/sites-enabled \
                        -v $PWD/fpm:/etc/php5/fpm \
                        -v $PWD/gc2/conf:/var/www/geocloud2/app/conf \
                        -e GC2_PASSWORD=$PG_PW \
                        -e TIMEZONE="$TIMEZONE" \
                        -e NR_INSTALL_KEY="$NR_INSTALL_KEY" \
                        -e NR_APP_NAME="$NR_APP_NAME" \
                        -p 80:80 -p 443:443 -p 1339:1339\
                        -t \
                        mapcentia/gc2core
                fi

#
# MapCache
#

#Create a persistence volume for MapCache.
if [[ $(docker ps -a --filter="name=mapcache-data" | grep mapcache-data) ]]
        then
                echo "mapcache-data already exists. Doing nothing."
        else
                echo "Creating a persistence volume for mapcache...."
                docker create --name mapcache-data mapcentia/mapcache
fi

check mapcache
if [[ $? = 1 ]]
        then
                echo "Running the MapCache container...."
                docker create \
                        --name mapcache \
                        --net container:gc2core \
                        --volumes-from gc2-data \
                        --volumes-from mapcache-data \
                        -t mapcentia/mapcache
fi

#The rest is optional.

#
# Kibana
#


check kibana
if [[ $? = 1 ]]
        then
                echo "Install kibana [y/N]"
                read CONF
                if [ "$CONF" = "y" ]; then

                        #Create a persistence volume for Kibana
                        if [[ $(docker ps -a --filter="name=kibana-data" | grep kibana-data) ]]
                                then
                                        echo "kibana-data already exists. Doing nothing."
                                else
                                        echo "Creating a persistence volume for kibana...."
                                        docker create --name kibana-data kibana
                        fi

                        echo "Running the Kibana container...."
                        docker create\
                                --name kibana \
                                --volumes-from kibana-data \
                                --link elasticsearch:elasticsearch \
                                -p 5601:5601 \
                                -t kibana
                fi
fi

#
# Logstash
#

check logstash
if [[ $? = 1 ]]
        then
                echo "Install logstash [y/N]"
                read CONF
                if [ "$CONF" = "y" ]; then
                        echo "Domain? [logstash]"
                        read CONF
                        if [ "$CONF" = "" ]; then
                                CONF=logstash
                        fi
                        echo "Running the Logstash container...."
                        docker create \
                                --name logstash \
                                --link elasticsearch:elasticsearch \
                                -v $PWD/logstash/certs:/certs \
                                -p 5043:5043 \
                                -p 1338:1338 \
                                -e "LOGSTASH_DOMAIN=$CONF" \
                                -t \
                                mapcentia/logstash
                fi
fi

#
#Logstashforwader
#

check logstashforwarder
if [[ $? = 1 ]]
        then
                echo "Install logstashforwarder [y/N]"
                read CONF
                if [ "$CONF" = "y" ]; then
                        echo "Domain? [logstash]"
                        read CONF
                        echo "Running the Logstash-forwarder container...."
                        if [ "$CONF" = "" ]; then
                                CONF=logstash
                                docker create \
                                        --name logstashforwarder \
                                        --link logstash:logstash \
                                        --volumes-from gc2core \
                                        -v $PWD/logstash/certs/:/certs \
                                        -e "MASTER=$CONF:5043" \
                                        -t \
                                        mapcentia/logstash-forwarder
                        else
                                docker create \
                                        --name logstashforwarder \
                                        --volumes-from gc2core \
                                        -v $PWD/logstash/certs/:/certs \
                                        -e "MASTER=$CONF:5043" \
                                        -t \
                                        mapcentia/logstash-forwarder
                        fi
                fi
fi

#
# Run Docker ps
#

sysctl -w vm.max_map_count=262144

docker ps -a
