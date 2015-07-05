FROM ubuntu:14.04

ENV DEBIAN_FRONTEND noninteractive

# Install Cozy tools and dependencies.
RUN apt-get update --quiet \
 && apt-get install --quiet --yes \
  build-essential \
  curl \
  git \
  imagemagick \
  language-pack-en \
  libssl-dev \
  libxml2-dev \
  libxslt1-dev \
  lsof \
  postfix \
  pwgen \
  python-dev \
  python-pip \
  python-setuptools \
  python-software-properties \
  software-properties-common \
  sqlite3 \
  wget
RUN update-locale LANG=en_US.UTF-8
RUN pip install \
  supervisor \
  virtualenv

RUN curl -sL https://deb.nodesource.com/setup_0.10 | bash \
  && apt-get install --quiet --yes nodejs

# Install CoffeeScript, Cozy Monitor and Cozy Controller via NPM.
RUN npm install -g \
  coffee-script \
  cozy-controller \
  cozy-monitor

# Create Cozy users, without home directories.
RUN useradd -M cozy \
 && useradd -M cozy-data-system \
 && useradd -M cozy-home

# Configure Supervisor.
ADD supervisor/supervisord.conf /etc/supervisord.conf
RUN mkdir -p /var/log/supervisor \
 && chmod 777 /var/log/supervisor \
 && /usr/local/bin/supervisord -c /etc/supervisord.conf

# Install Cozy Indexer.
RUN mkdir -p /usr/local/cozy-indexer \
 && cd /usr/local/cozy-indexer \
 && git clone https://github.com/cozy/cozy-data-indexer.git \
 && cd /usr/local/cozy-indexer/cozy-data-indexer \
 && virtualenv --quiet /usr/local/cozy-indexer/cozy-data-indexer/virtualenv \
 && . ./virtualenv/bin/activate \
 && pip install -r /usr/local/cozy-indexer/cozy-data-indexer/requirements/common.txt \
 && chown -R cozy:cozy /usr/local/cozy-indexer

# Start up background services and install the Cozy platform apps.
ENV NODE_ENV production

# Configure Postfix with default parameters.
# TODO: Change mydomain.net?
RUN echo "postfix postfix/mailname string mydomain.net" | debconf-set-selections \
 && echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections \
 && echo "postfix postfix/destinations string mydomain.net, localhost.localdomain, localhost " | debconf-set-selections \
 && postfix check

# Import Supervisor configuration files.
ADD supervisor/cozy-controller.conf /etc/supervisor/conf.d/cozy-controller.conf
ADD supervisor/cozy-indexer.conf /etc/supervisor/conf.d/cozy-indexer.conf
ADD supervisor/postfix.conf /etc/supervisor/conf.d/postfix.conf
RUN chmod 0644 /etc/supervisor/conf.d/*

# Clean APT cache for a lighter image.
RUN apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY start /start

EXPOSE 9104

VOLUME ["/etc", "/usr/local/cozy"]

CMD /start
