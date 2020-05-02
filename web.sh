#!/bin/bash

function version()
{
    echo ""
    echo "#################################"
    echo "##         web mac 1.0         ##"
    echo "## runs on top of brew package ##"
    echo "#################################"
    echo ""
}

function command_not_supported()
{
	echo ""
	echo "command not supported"
	echo ""
}

function update_script()
{
    command_not_supported
}

function site_enable()
{
    echo ""
    echo "enable ${3}..."
    ln -fs /usr/local/etc/nginx/sites-available/${3} /usr/local/etc/nginx/sites-enabled/${3}
    brew services reload nginx
    echo "${3} enabled!"
    echo ""
}

function site_disable()
{
    echo ""
    echo "disable ${3}..."
    rm -f /usr/local/etc/nginx/sites-enabled/${3} 2> /dev/null
    brew services reload nginx
    echo "${3} disabled!"
    echo ""
}

function site_create_database()
{
    echo ""
    echo "create database for ${3}..."

    export LC_CTYPE=C
    local name=${3//[^a-z0-9]/_}
    local pass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

    #create mysql user and database
    echo "### MySQL Config ###
database=${name}
username=${name}
password=${pass}" > /usr/local/var/www/${3}/conf/mysql.conf

    #create database
    mysql --user=$(whoami) -e "CREATE DATABASE IF NOT EXISTS ${name};
    CREATE USER '${name}'@'localhost' IDENTIFIED BY '${pass}';
    GRANT ALL PRIVILEGES ON ${name}.* TO '${name}'@'localhost';
    CREATE USER '${name}'@'%' IDENTIFIED BY '${pass}';
    GRANT ALL PRIVILEGES ON ${name}.* TO '${name}'@'%';
    FLUSH PRIVILEGES;" 2> /dev/null

    echo "database created!"
}

function site_create_web_directory()
{
    echo ""
    echo "create web directory for ${3}..."
    mkdir -p /usr/local/var/www/${3}/src/public
    mkdir -p /usr/local/var/www/${3}/conf
    mkdir -p /usr/local/var/www/${3}/log
    echo "directory created!"
}

function site_create_nginx_conf()
{
    echo ""
    echo "create nginx config for ${3}..."
    mkdir -p /usr/local/etc/nginx/sites-available
    mkdir -p /usr/local/etc/nginx/sites-enabled
    echo "### ${3} ###
server {
    listen 8080;

    if (\$host = www.${3}) {
        return 301 \$scheme://${3}\$request_uri;
    }

    # Webroot Directory
    root /usr/local/var/www/${3}/src/public;
    index index.php index.html index.htm;

    # Your Domain Name
    server_name ${3} www.${3};

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # PHP-FPM Configuration Nginx
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        
    }

    # Log files for Debugging
    access_log /usr/local/var/www/${3}/log/access.log;
    error_log /usr/local/var/www/${3}/log/error.log;
}
" > /usr/local/etc/nginx/sites-available/${3}
    echo "nginx config created!"
}

function site_install_helloworld()
{
    echo ""
    echo "install helloworld in ${3}..."
    mv /usr/local/var/www/${3}/src /usr/local/var/www/${3}/src-$(date +'%Y%m%d%H%M%S')-bak
    mkdir -p /usr/local/var/www/${3}/src/public
    echo "<h1>${3}</h1>
    <ul>
    	<li><a href=\"info.php\">info.php</a></li>
    	<li><a href=\"db.php\">db.php</a></li>
    </ul>
    " > /usr/local/var/www/${3}/src/public/index.php
    echo "<?php phpinfo();" > /usr/local/var/www/${3}/src/public/info.php
    . /usr/local/var/www/${3}/conf/mysql.conf
    echo "<?php
\$host = 'localhost';
\$username = '${username}';
\$password = '${password}';
\$database = '${database}';

\$conn = new mysqli(\$host, \$username, \$password, \$database);

if (\$conn->connect_error) {
    die('Connection failed: ' . \$conn->connect_error);
}

echo 'Connected successfully';" > /usr/local/var/www/${3}/src/public/db.php
    echo "helloworld installed!"
}

function site_install_laravel()
{
    echo ""
    echo "install laravel in ${1}..."
    local package="laravel/laravel"
    if [ -n "$5" ]; then
    	package="laravel/laravel:${5}"
    fi
    cd /usr/local/var/www/${3} \
        && rm -Rf laravel \
        && composer create-project ${package} laravel --prefer-dist \
        && cd laravel \
        && . /usr/local/var/www/${3}/conf/mysql.conf \
        && cp .env .env.bak \
        && sed "s/APP_NAME=Laravel/APP_NAME=${3}/g" .env.bak \
        | sed "s/APP_URL=http:\/\/localhost/APP_URL=http:\/\/${3}/g" \
        | sed "s/DB_DATABASE=laravel/DB_DATABASE=${database}/g" \
        | sed "s/DB_USERNAME=root/DB_USERNAME=${username}/g" \
        | sed "s/DB_PASSWORD=/DB_PASSWORD=${password}/g" > .env \
        && cd .. \
        && mv src src-$(date +'%Y%m%d%H%M%S')-bak \
        && mv laravel src
    echo "laravel installed!"
}

function site_install_wordpress()
{
    echo ""
    echo "install wordpress in ${3}..."
    local package="johnpbloch/wordpress"
    if [ -n "$5" ]; then
    	package="johnpbloch/wordpress:${5}"
    fi
    cd /usr/local/var/www/${3} \
        && rm -Rf wp \
        && composer create-project ${package} wp --prefer-dist \
        && cd wp \
        && mv wordpress public \
        && . /usr/local/var/www/${3}/conf/mysql.conf \
        && cd public \
        && sed "s/database_name_here/$database/g" wp-config-sample.php \
        | sed "s/username_here/$username/g" \
        | sed "s/password_here/$password/g" > wp-config.php \
        && STR_PATTERN='put your unique phrase here' \
        && STR_REPLACE=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/) \
        && printf '%s\n' "g/$STR_PATTERN/d" a "$STR_REPLACE" . w \
        | ed -s wp-config.php \
        && cd ../.. \
        && mv src src-$(date +'%Y%m%d%H%M%S')-bak \
        && mv wp src
    echo "wordpress installed!"
}

function site_install_phpmyadmin()
{
    echo ""
    echo "install phpmyadmin in ${3}..."
    export LC_CTYPE=C
    local blowfish_secret=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    local package="phpmyadmin/phpmyadmin"
    if [ -n "$5" ]; then
    	package="phpmyadmin/phpmyadmin:${5}"
    fi
    cd /usr/local/var/www/${3} \
        && rm -Rf phpmyadmin \
        && composer create-project ${package} phpmyadmin --prefer-dist \
        && mv src src-$(date +'%Y%m%d%H%M%S')-bak \
        && mkdir src \
        && mv phpmyadmin src/public
    cd /usr/local/var/www/${3} \
        && sed "s/blowfish_secret'\] = ''/blowfish_secret'\] = '${blowfish_secret}'/g" src/public/config.sample.inc.php \
        | sed "s/AllowNoPassword'\] = false/AllowNoPassword'\] = true/g" > src/public/config.inc.php
    echo "phpmyadmin installed!"
}

function site_install()
{
    if [ -z "$4" ] || [ ${4} == "helloworld" ]; then
        site_install_helloworld $@
    elif [ ${4} == "laravel" ]; then
        site_install_laravel $@
    elif [ ${4} == "wp" ] || [ ${4} == "wordpress" ]; then
        site_install_wordpress $@
    elif [ ${4} == "phpmyadmin" ]; then
        site_install_phpmyadmin $@
    else
        echo "${4} command not supported"
    fi
}

function site_create()
{
	if [ -z "$3" ]; then
		command_not_supported
		return
	fi
    #check is domain exist (and sites-available)
    echo ""
    echo "create ${3}..."

    #create web root and default index.php file
    site_create_web_directory $@

    #create database
    site_create_database $@

    #create nginx configuration
    site_create_nginx_conf $@

    #enable site
    site_enable $@

    #install application
    site_install $@

    echo ""
    echo "${3} created!"
    echo ""
}

function site_delete_nginx_conf()
{
    echo ""
    echo "delete nginx conf ${3}..."
    rm -f /usr/local/etc/nginx/sites-available/${3} 2> /dev/null
    echo "nginx conf ${3} deleted!"
}

function site_delete_web_directory()
{
    echo ""
    echo "delete ${3} web directory..."
    rm -Rf /usr/local/var/www/${3} 2> /dev/null
    echo "web directory deleted!"
}

function site_delete_database()
{
    echo ""
    echo "delete database ${3}..."
    local name=${3//[^a-z0-9]/_}
    mysql --user=$(whoami) -e "DROP DATABASE IF EXISTS ${name};
    DROP USER '${name}'@'localhost';
    DROP USER '${name}'@'%';
    FLUSH PRIVILEGES;" 2> /dev/null
    echo "database deleted!"
}

function site_delete()
{
    echo ""
    echo "delete ${3}..."
    
    #delete site enable
    site_disable $@
    
    #site available
    site_delete_nginx_conf $@

    #delete web directory
    site_delete_web_directory $@

    #delete database
    site_delete_database $@

    echo ""
    echo "${3} deleted!"
}

function site_list()
{
    echo ""
    echo "all sites:"
    ls /usr/local/etc/nginx/sites-available  2> /dev/null | cat
    echo ""
    echo "active sites:"
    ls /usr/local/etc/nginx/sites-enabled 2> /dev/null | cat
    echo ""
}

function site()
{
    if [ ${2} == "create" ]; then
        site_create $@
    elif [ ${2} == "delete" ]; then
        site_delete $@
    elif [ ${2} == "install" ]; then
        site_install $@
    elif [ ${2} == "enable" ]; then
        site_enable $@
    elif [ ${2} == "disable" ]; then
        site_disable $@
    elif [ ${2} == "list" ]; then
        site_list
    else
        echo "command not supported"
    fi
}

function host()
{
    if [ ${2} == "add" ]; then
        echo "127.0.0.1 ${3}" >> /etc/hosts
        echo "::1 ${3}" >> /etc/hosts
    elif [ ${2} == "remove" ]; then
        sed "s/127.0.0.1 ${3}//" /etc/hosts > hosts.bak && mv hosts.bak /etc/hosts
        sed "s/::1 ${3}//" /etc/hosts > hosts.bak && mv hosts.bak /etc/hosts
    else
        echo "command not supported"
    fi
    sed -i '' '/^$/d' /etc/hosts
}

function install()
{
    echo ""
    echo "install web mac..."

    echo ""
    echo "install web.sh script..."
    mkdir -p ~/.web-mac
    cp web.sh ~/.web-mac/web.sh
    ln -sf ~/.web-mac/web.sh /usr/local/bin/web
    echo "script installed!"

    #install mariadb
    echo ""
    echo "install mariadb..."
    if [ "$(brew info mariadb | grep 'Not installed')" == "Not installed" ]; then
        brew install mariadb
        brew services start mariadb
        echo "mariadb installed!"
    else
        echo "mariadb already installed!"
    fi

    #install php
    echo ""
    echo "install php..."
    if [ "$(brew info php | grep 'Not installed')" == "Not installed" ]; then
        brew install php
        brew services start php
        echo "php installed!"
    else
        echo "php already installed!"
    fi

    #install nginx
    echo ""
    echo "install nginx..."
    if [ "$(brew info nginx | grep 'Not installed')" == "Not installed" ]; then
        brew install nginx
        echo "nginx installed!"
    else
        echo "nginx already installed!"
    fi

    #configure nginx
    echo ""
    echo "configure nginx..."
    cd /usr/local/etc/nginx \
        && sed "s/include servers/include sites-enabled/g" nginx.conf.default > nginx.conf \
        && mkdir -p sites-available \
        && mkdir -p sites-enabled
    brew services reload nginx
    echo "nginx configured!"

    #install composer
    echo ""
    echo "install composer..."
    if [ "$(brew info composer | grep 'Not installed')" == "Not installed" ]; then
        brew install composer
        echo "composer installed!"
    else
        echo "composer already installed!"
    fi

    #install node
    echo ""
    echo "install node..."
    if [ "$(brew info node | grep 'Not installed')" == "Not installed" ]; then
        brew install node
        echo "node installed!"
    else
        echo "node already installed!"
    fi

    echo ""
    echo "web mac installed!"
    echo ""
}

function uninstall()
{
    echo ""
    echo "uninstall web"
    echo ""

    echo "uninstall mariadb..."
    brew services stop mariadb
    brew uninstall mariadb
    echo "mariadb uninstalled!"

    echo ""
    echo "uninstall php..."
    brew services stop php
    brew uninstall php
    echo "php uninstalled!"

    echo ""
    echo "uninstall nginx..."
    brew services stop nginx
    brew uninstall nginx
    echo "nginx uninstalled!"

    echo ""
    echo "uninstall composer..."
    brew uninstall composer
    echo "composer uninstalled!"

    echo ""
    brew uninstall node
    echo "node uninstalled!"

    #remove installation
    echo ""
    echo "remove web.sh script..."
    rm -f /usr/local/bin/web
    rm -Rf ~/.web-mac
    echo "web.sh removed!"
    
    echo ""
    echo "web uninstalled!"
    echo ""


}

function main()
{
    if [ -z "$1" ] || [ ${1} == "-v" ] || [ ${1} == "version" ]; then
        version
    elif [ ${1} == "update" ]; then
        update_script $@
    elif [ ${1} == "site" ]; then
        site $@
    elif [ ${1} == "host" ]; then
        host $@
    elif [ ${1} == "install" ]; then
        install
    elif [ ${1} == "uninstall" ]; then
        uninstall
    else
        command_not_supported
    fi    
}

###========###MAIN###========###

main $@
