FROM debian:jessie

ENV MYSQL_PWD password

COPY php-build /php-build/
WORKDIR /php-build/

# Get our environment set up
RUN echo "deb-src http://deb.debian.org/debian jessie main" >> /etc/apt/sources.list && \
    echo "deb-src http://deb.debian.org/debian-security/ jessie/updates main" >> /etc/apt/sources.list && \
    echo "deb-src http://deb.debian.org/debian jessie-updates main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get -y install debconf-utils && \
    echo "mysql-server mysql-server/root_password password $MYSQL_PWD" | debconf-set-selections && \
    echo "mysql-server mysql-server/root_password_again password $MYSQL_PWD" | debconf-set-selections && \
    apt-get -y install build-essential && \
    apt-get -y build-dep php5 && \
    tar xvf php-4.4.9.tar.bz2 && \
    tar xvf openssl-0.9.8x.tar.gz && \
    ln -s /usr/lib/x86_64-linux-gnu/libjpeg.so /usr/lib/ && \
    ln -s /usr/lib/x86_64-linux-gnu/libpng.so /usr/lib/ && \
    ln -s /usr/lib/x86_64-linux-gnu/libmysqlclient.so.18 /usr/lib/ && \
    ln -s /usr/lib/x86_64-linux-gnu/libexpat.so /usr/lib/ && \
    ln -s /usr/lib/x86_64-linux-gnu/libmysqlclient.so /usr/lib/libmysqlclient.so && \
    mkdir /usr/kerberos && \
    ln -s /usr/lib/x86_64-linux-gnu /usr/kerberos/lib

# Build OpenSSL 0.9.8x, since PHP 4 refuses to build with OpenSSL 1.0.0+
WORKDIR /php-build/openssl-0.9.8x
RUN ./config --prefix=/usr/local/openssl-0.9.8 && make -j8 && make install_sw

# Build PHP 4.4.9
WORKDIR /php-build/php-4.4.9/
RUN ./configure \
    --with-pdo-pgsql \
    --with-zlib-dir \
    --enable-mbstring \
    --with-libxml-dir=/usr \
    --enable-soap \
    --enable-calendar \
    --with-curl \
    --with-mcrypt \
    --with-zlib \
    --with-gd \
    --with-pgsql \
    --disable-rpath \
    --enable-inline-optimization \
    --with-bz2 \
    --with-zlib \
    --enable-sockets \
    --enable-sysvsem \
    --enable-sysvshm \
    --enable-pcntl \
    --enable-mbregex \
    --with-mhash \
    --enable-zip \
    --with-pcre-regex \
    --with-mysql=/usr \
    --with-mysql-sock=/var/run/mysqld/mysqld.sock \
    --with-jpeg-dir=/usr \
    --with-png-dir=/usr \
    --enable-gd-native-ttf \
    --with-openssl=/usr/local/openssl-0.9.8 \
    --with-openssl-dir=/usr/local/openssl-0.9.8 \
    --with-libdir=/lib/x86_64-linux-gnu \
    --enable-ftp \
    --with-imap \
    --with-imap-ssl \
    --with-kerberos \
    --with-gettext \
    --with-expat-dir=/usr \
    --enable-fastcgi && \
    make -j8 && \
    make install

# Install Apache and configure it to use PHP via FastCGI
RUN apt-get -y install apache2 libapache2-mod-fcgid && \
    a2enmod fcgid && \
    cp /php-build/php-4.4.9/php.ini-dist /usr/local/lib/php.ini && \
    echo "cgi.fix_pathinfo=1" >> /usr/local/lib/php.ini && \
    sed -i 's/Options Indexes FollowSymLinks/Options Indexes FollowSymLinks ExecCGI/' /etc/apache2/apache2.conf

COPY httpd-foreground /usr/local/bin/
COPY php-fcgid.conf /etc/apache2/conf-available/php-fcgid.conf

RUN ln -s /etc/apache2/conf-available/php-fcgid.conf /etc/apache2/conf-enabled/php-fcgid.conf && \
    chmod +x /usr/local/bin/httpd-foreground

EXPOSE 80
CMD ["httpd-foreground"]
