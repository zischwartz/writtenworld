# STRUCTURE

# path is to:
# project_name/
# 		-fabfile.py 		(local)
# 		-project/  			(by git/fab, this is the actual code)
# 		-gunicorn_settings 	(by fab)
# 		-nginx_settings 	(by fab)
# 		-git.repo  			(by fab/git)
# 
# 

from fabric.api import *
from fabric.contrib.console import confirm
from contextlib import contextmanager as _contextmanager
import os.path

env.user = 'ec2-user'
env.hosts = ['23.21.103.176']


env.project_name = 'scribverse'
env.code_dir = "project"
#this is only on the server now

env.path = '/home/'+ env.user +'/' + env.project_name 	#basically our working directory

env.code_path = env.path + '/' + env.code_dir 			#where the python/django code goes



def prepare_server():
	sudo('yum install git nginx -y mercurial python-devel make') #removed git-core
        sudo('yum -y install tcsh scons gcc-c++ glibc-devel')
	# sudo('yum -y memcached')

	# MONGODB
	# sudo('yum -y install boost-devel pcre-devel js-devel readline-devel')
	sudo('yum -y install boost-devel-static readline-static ncurses-staticl')
	#----for 32 bit
	# sudo('yum install http://downloads-distro.mongodb.org/repo/redhat/os/i686/RPMS/mongo-10gen-2.0.0-mongodb_1.i686.rpm -y --nogpgcheck')
	# sudo('yum install http://downloads-distro.mongodb.org/repo/redhat/os/i686/RPMS/mongo-10gen-server-2.0.0-mongodb_1.i686.rpm -y --nogpgcheck')

        #---64 bit at http://downloads-distro.mongodb.org/repo/redhat/os/
	sudo('yum install http://downloads-distro.mongodb.org/repo/redhat/os/x86_64/RPMS/mongo-10gen-2.0.4-mongodb_1.x86_64.rpm -y --nogpgcheck')
	sudo('yum install http://downloads-distro.mongodb.org/repo/redhat/os/x86_64/RPMS/mongo-10gen-server-2.0.4-mongodb_1.x86_64.rpm -y --nogpgcheck')
	sudo('mkdir -p /data/db/')
	sudo('sudo chown `id -u` /data/db')

        sudo('yum localinstall --nogpgcheck http://nodejs.tchol.org/repocfg/amzn1/nodejs-stable-release.noarch.rpm -y')
        sudo('yum install nodejs-compat-symlinks npm -y')

        sudo('yum install openssl openssl-devel -y') #for mongoose-auth
	# sudo('yum install mysql mysql-server mysql-client mysql-devel -y')

def install_redis():
    run('wget http://redis.googlecode.com/files/redis-2.4.15.tar.gz')
    run('tar xzf redis-2.4.15.tar.gz')
    with cd('redis-2.4.15'):
        run('make')
        run('make test')
        sudo('make install') #maybe not sudo?
        with cd('utils'):
            sudo('./install_server.sh') #this requires answers

    with cd(env.project_name):
        run('npm install hiredis redis')




def setup_remote():
        with settings(warn_only=True):
            run('mkdir %s' % env.project_name)
            with cd(env.project_name):
                run("git init --bare repo.git")
                run('mkdir %s' % env.code_dir)
                with cd("repo.git/hooks/"):
                    run("""echo "%s" > post-receive""" % prhook)
                    run("chmod +x post-receive") 

def add_remote():
	#now lets add this as a remote to our local git repo
	local("git remote add ec2 %s@%s:%s/repo.git" % (env.user, env.host, env.path))


def push():
	local("git push ec2 master")

prhook = """
#!/bin/sh
GIT_WORK_TREE=%s git checkout -f
"""  % env.code_path
#from # http://toroid.org/ams/git-website-howto



def install_reqs():
    with cd(env.code_path):
        sudo('npm install connect')
        sudo('npm install now')
        sudo('npm install express')
        sudo('npm install mongoose')
        sudo('npm install jade')
        sudo('npm install mongoose-auth')

        sudo('npm install -g nodemon')
        sudo('npm install -g coffee-script')
        # i also did
        # npm install mongodb --mongodb:native       

def start_db():
    sudo('mongod --fork --logpath /var/log/mongodb.log --logappend')

def start_dev_server():
	with virtualenv():
		with cd(env.code_path):
			run("python manage.py runserver") # 0.0.0.0:80")   #--settings=settings 0.0.0.0:8080")


def config_nginx():
	with cd(env.path):					
		# Put our django specific conf in the main dir
		run("""echo "%s" > django_nginx.conf""" % nginx_config)
		#link to it in nginx's conf
		sudo("ln -s  %s/django_nginx.conf /etc/nginx/conf.d/django_nginx.conf" % env.path)
		# and start it
		sudo("nginx -c %s/nginx.conf" % env.code_dir)

def start_g():
		with virtualenv():
			with cd(env.code_path):
				run("gunicorn_django -b 0.0.0.0:8000")

def setup_mysql():
    with virtualenv():
      with cd(env.code_path):
        run("rm settings_local.py")
        run("rm settings_local.pyc")
        run("echo '%s' >> email_details.py" % email_details) #untested, in .gitignore
      sudo("/etc/init.d/mysqld start")
      run("/usr/bin/mysqladmin -u root password 'ywot'")
      # run("mysqladmin create text")


def config_supervisor():
  with cd(env.path):
    # echo_supervisord_conf >
    run('echo_supervisord_conf > supervisord.conf')  #this generates a sample config
    run("echo '%s' >>  supervisord.conf " % supervisor_config)   #and this appends it



# export PYTHONPATH="/home/ec2-user/echo_world/code"

# chmod +r static/ -R
# chmod +r static/ -R
# no dice

# sudo chown -R nginx static/
# still no dice

# chmod +rx -R static/ 

# sudo chmod 777  -R static/ 

	# git remote add webfaction zazerr@zazerr.webfaction.com:webapps/yourworld/myproject	
	# Add the remote locally, yo
# git remote add webfaction zazerr@zazerr.webfactional.com:webapps/yourworld/myproject
# git push webfaction master
# http://docs.webfaction.com/software/git.html

# WORKED
# git remote add webfaction zazerr@zazerr.webfactional.com:~/webapps/yourworld/myproject/repo.git


email_details = """
EMAIL_HOST = 'smtp.gmail.com'     
EMAIL_HOST_USER = 'writtenworldmail@gmail.com'
EMAIL_HOST_PASSWORD = 'clayshirky'
EMAIL_PORT = 587
EMAIL_USE_TLS = True

"""



# activate gunicorn with
# /home/ec2-user/echo_world/venv/bin/gunicorn_django -b 0.0.0.0:8000 /home/ec2-user/echo_world/project/settings.py

supervisor_config = """
[program:gunicorn_django]
command=%s/venv/bin/gunicorn_django -b 0.0.0.0:8000 %s/settings.py
user=root
autostart=true
autorestart=true
  """  % (env.path, env.code_path)


# This gets placed in the directory above the code_dir. In the code dir is the basic nginx config, which will reference a symbolic link to this file.
#kinda silly, but the only change to the basic nginx_config is that we made user root...
nginx_config = """
server {
    listen   80 default_server;
    server_name example.com;
    # no security problem here, since / is alway passed to upstream
    root %s;
    # serve directly - analogous for static/staticfiles
    location /static/ {

    }
    location /admin/media/ {
        # this changes depending on your python version
        root %s/venv/lib/python2.6/site-packages/django/contrib;
    }
    location / {
        proxy_pass_header Server;
        proxy_set_header Host \$"http_host";
        proxy_redirect off;
        proxy_set_header X-Real-IP \$"remote_addr";
        proxy_set_header X-Scheme \$"scheme";
        proxy_connect_timeout 10;
        proxy_read_timeout 10;
        proxy_pass http://localhost:8000/;
    }
    # what to serve if upstream is not available or crashes
    error_page 500 502 503 504 /media/50x.html;
}""" % (env.code_path, env.path)



gunicorn_nginx_config = """
# This is example contains the bare mininum to get nginx going with
# Gunicornservers.  

worker_processes 1;


pid /tmp/nginx.pid;
error_log /tmp/nginx.error.log;

events {
  worker_connections 1024; # increase if you have lots of clients
  accept_mutex off; # on - if nginx worker_processes > 1
  # use epoll; # enable for Linux 2.6+
  # use kqueue; # enable for FreeBSD, OSX
}

http {
  # nginx will find this file in the config directory set at nginx build time
  include mime.types;

  # fallback in case we can't determine a type
  default_type application/octet-stream;

  # click tracking!
  access_log /tmp/nginx.access.log combined;

  # you generally want to serve static files with nginx since neither
  # Unicorn nor Rainbows! is optimized for it at the moment
  sendfile on;

  tcp_nopush on; # off may be better for *some* Comet/long-poll stuff
  tcp_nodelay off; # on may be better for some Comet/long-poll stuff

  # we haven't checked to see if Rack::Deflate on the app server is
  # faster or not than doing compression via nginx.  It's easier
  # to configure it all in one place here for static files and also
  # to disable gzip for clients who don't get gzip/deflate right.
  # There are other other gzip settings that may be needed used to deal with
  # bad clients out there, see http://wiki.nginx.org/NginxHttpGzipModule
  gzip on;
  gzip_http_version 1.0;
  gzip_proxied any;
  gzip_min_length 500;
  gzip_disable "MSIE [1-6]\.";
  gzip_types text/plain text/html text/xml text/css
             text/comma-separated-values
             text/javascript application/x-javascript
             application/atom+xml;

  # this can be any application server, not just Unicorn/Rainbows!
  upstream app_server {
    # fail_timeout=0 means we always retry an upstream even if it failed
    # to return a good HTTP response (in case the Unicorn master nukes a
    # single worker for timing out).

    # for UNIX domain socket setups:
    server unix:/tmp/gunicorn.sock fail_timeout=0;

    # for TCP setups, point these to your backend servers
    # server 192.168.0.7:8080 fail_timeout=0;
    # server 192.168.0.8:8080 fail_timeout=0;
    # server 192.168.0.9:8080 fail_timeout=0;
  }

  server {
    # listen 80 default deferred; # for Linux
    # listen 80 default accept_filter=httpready; # for FreeBSD
    listen 80 default_server;

    client_max_body_size 4G;
    server_name _;

    # ~2 seconds is often enough for most folks to parse HTML/CSS and
    # retrieve needed images/icons/frames, connections are cheap in
    # nginx so increasing this is generally safe...
    keepalive_timeout 5;

    # path for static files
    root %s;

    location / {
      # an HTTP header important enough to have its own Wikipedia entry:
      #   http://en.wikipedia.org/wiki/X-Forwarded-For
      # proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;


      # enable this if and only if you use HTTPS, this helps Rack
      # set the proper protocol for doing redirects:
      # proxy_set_header X-Forwarded-Proto https;

      # pass the Host: header from the client right along so redirects
      # can be set properly within the Rack application
      # proxy_set_header Host $http_host;
      # proxy_set_header X-Forwarded-Host $host;

      # we don't want nginx trying to do something clever with
      # redirects, we set the Host: header above already.
      proxy_redirect off;


      # Comet/long-poll stuff.  It's also safe to set if you're
      # using only serving fast clients with Unicorn + nginx.
      # Otherwise you _want_ nginx to buffer responses to slow
      # clients, really.
      # proxy_buffering off;

      # Try to serve static files from nginx, no point in making an
      # *application* server like Unicorn/Rainbows! serve static files.
      if (!-f $request_filename) {
        proxy_pass http://app_server;
        break;
      }
    }

    # Error pages
    error_page 500 502 503 504 /500.html;
    location = /500.html {
      root /path/to/app/current/public;
    }
  }
} """  % env.code_path
