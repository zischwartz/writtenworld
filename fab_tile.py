
from fabric.api import *
from fabric.contrib.console import confirm
from contextlib import contextmanager as _contextmanager
import os.path
from boto.ec2.connection import EC2Connection

env.user = 'ubuntu'
env.hosts = ['ec2-107-21-165-248.compute-1.amazonaws.com']

conn = EC2Connection('AKIAJRCNWZLCRGKOA7FA', 'hOBw0sNx4iRurKDvXnSI+GokaeeffL1DYFJ6g95x')

def start_micro():
    conn.run_instances(
            'ami-baba68d3',
            key_name='zach',
            instance_type='t1.micro',
            placement='us-east-1a',
            security_groups=['quick-start-1'])
            # instance_type='m2.2xlarge',

def install():
    sudo("apt-get update")
    sudo("apt-get upgrade -y")
    sudo("apt-get install git python-dev make -y")

    sudo("apt-get install postgresql-9.1 postgresql-server-dev-9.1 -y")

    # for osm2pgsql
    sudo("apt-get install build-essential libxml2-dev libgeos-dev libpq-dev libbz2-dev proj libtool automake -y")
    sudo("apt-get install subversion  protobuf-compiler libprotobuf-dev libprotoc-dev -y")

    # for post gis
    sudo("apt-get -y install postgis postgresql-contrib-9.1 postgis  gdal-bin binutils libgeos-3.2.2 libgeos-c1 libgeos-dev libgdal1-dev libxml2 libxml2-dev libxml2-dev checkinstall proj libpq-dev")

    #for pil
    sudo("apt-get install libjpeg8 libjpeg62-dev libfreetype6 libfreetype6-dev -y")
    sudo("apt-get install python-imaging -y")

    # get stable mapnik
    sudo("add-apt-repository ppa:mapnik/nightly-2.0 -y")
    sudo("apt-get update")
    sudo("aptitude install pgsql-dev libboost1.37-dev libltdl7-dev proj python-cairo libcairomm-1.0-dev -y" )
    sudo("apt-get install libmapnik mapnik-utils python-mapnik -y")

    #mapnik depends
    sudo("aptitude install libboost-iostreams-dev -y")
    sudo("apt-get install libboost-thread-dev libfreetype6-dev libxml2-dev libtiff4-dev libboost-regex-dev libboost-filesystem-dev libboost-python-dev -y")
    # postgresql-dev supposedly, but can't find it
    
    # ADD libpq-dev

    # sudo apt-get install -y g++ cpp \
    # libicu-dev \
    # libboost-filesystem-dev \
    # libboost-program-options-dev \
    # libboost-python-dev libboost-regex-dev \
    # libboost-system-dev libboost-thread-dev \
    # python-dev libxml2 libxml2-dev \
    # libfreetype6 libfreetype6-dev \
    # libjpeg-dev \
    # libltdl7 libltdl-dev \
    # libpng-dev \
    # libgeotiff-dev libtiff-dev libtiffxx0c2 \
    # libcairo2 libcairo2-dev python-cairo python-cairo-dev \
    # libcairomm-1.0-1 libcairomm-1.0-dev \
    # ttf-unifont ttf-dejavu ttf-dejavu-core ttf-dejavu-extra \
    # git build-essential python-nose
    
    # python scons/scons.py DEBUG=y 

    sudo("apt-get install python-pip -y")

    # for tilestache
    sudo("pip install modestmaps simplejson werkzeug ")
    sudo("pip install tilestache ")
    # sudo easy_install psycopg2 ?

def get_repos():
    run('git clone https://github.com/migurski/TileStache.git')
    
    run('svn co http://svn.openstreetmap.org/applications/utils/export/osm2pgsql/')
    with cd('osm2pgsql/'):
        run('./autogen.sh')
        run('./configure')
        run("sed -i 's/-g -O2/-O2 -march=native -fomit-frame-pointer/' Makefile")
    
    # IMPORTANT   for 64 bit support 
    # IMPORTANT    
    #should use sed to do this but w/e
    # uncomment #define OSMID64 in osmtypes.h
    # then make!

def mount():
    sudo("mkdir /mnt/ebs")
    sudo("mount /dev/xvdf /mnt/ebs")
    


def reformat_and_mount():
    #first attach it with the aws console to the default ('dev/sdf') but it'll end up at 'xvdf' probably
    
    run("cat /proc/partitions") #show whats up

    sudo("mke2fs -F -j /dev/xvdf")
    mount()

    # sudo("mkdir /mnt/ebs")
    # sudo("mount /dev/xvdf /mnt/ebs")
    

def start_ts():
    with cd("TileStache"):
        sudo("./scripts/tilestache-server.py -i 0.0.0.0 -p  80")

        #check it out at host   /osm/preview.html

#/usr/lib/postgresql/9.1/bin/pg_ctl

# INSTALL POSTGIS
def install_postgis():
        pass
# https://raw.github.com/gist/1481128/8493ea2971b0d69dce558d7f43bf1c799ba52ff4/gistfile1.txt
# get that, and execute it

# sudo TileStache/scripts/tilestache-server.py -i 0.0.0.0 -p 80 -c tilestache.cfg

def link_mapnik_deps():
    run("git clone ----------- ")
    with cd("mapnik"):
        run("python scons/scons.py PGSQL_INCLUDES=/usr/include/postgresql PROJ_INCLUDES=/usr/include PROJ_LIBS=/usr/lib XMLPARSER=libxml2"
    
    #probably not neccesary with ubunut?    
    # with cd("/usr/lib"):
    #     sudo("ln -s libboost_filesystem.so libboost_filesystem-mt.so")
    #     sudo("ln -s libboost_regex.so libboost_regex-mt.so")
    #     sudo("ln -s libboost_iostreams.so libboost_iostreams-mt.so")
    #     sudo("ln -s libboost_program_options.so libboost_program_options-mt.so")
    #     sudo("ln -s libboost_thread.so libboost_thread-mt.so")
    #     sudo("ln -s libboost_python.so libboost_python-mt.so")
    #     sudo("ln -s libgdal1.3.2.so libgdal.so")


def setup_db():
    # stop it
    sudo("/usr/lib/postgresql/9.1/bin/pg_ctl stop -D /var/lib/postgresql/9.1/main")
    #init it where we want it (will want 0700 permissions)
    sudo("/usr/lib/postgresql/9.1/bin/pg_ctl init -D /mnt/ebs/postgresql/data/") 
    #start it
    run("/usr/lib/postgresql/9.1/bin/pg_ctl -D /mnt/ebs/postgresql/data -l logfile start")
    
    #as postgres
    run("psql -d gis -f /usr/share/postgresql/9.1/contrib/postgis-1.5/postgis.sql")

def install_apache():
    sudo("sudo apt-get install apache2 apache2-threaded-dev apache2-mpm-prefork apache2-utils libagg-dev -y")

def download_boundaries():
    #these are required or maybe nice to have? w/e
    run("mkdir boundaries")
    with cd("boundaries"):
        run("wget http://tile.openstreetmap.org/world_boundaries-spherical.tgz")
        run("wget http://tile.openstreetmap.org/processed_p.tar.bz2 ") 
        run("wget http://tile.openstreetmap.org/shoreline_300.tar.bz2")
        run("wget http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/10m-populated-places.zip")    
        run("wget http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/110m/cultural/110m-admin-0-boundary-lines.zip ")
 

