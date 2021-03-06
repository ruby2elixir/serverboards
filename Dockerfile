FROM ubuntu:16.04

ENV LANG=C.UTF-8

RUN apt-get -y update && apt-get install -y \
  postgresql \
  supervisor inotify-tools

RUN useradd serverboards -m -U

# Uncompress serverboards
ADD rel/serverboards.tar.gz /opt/
RUN chown :serverboards /opt/serverboards/

# copy some extra data
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY serverboards.sh /opt/serverboards/

ENV SERVERBOARDS_DB=postgres://serverboards:serverboards@localhost:5432/serverboards

# go !
EXPOSE 8080
VOLUME /var/lib/postgresql/9.5/main/ /home/serverboards/ /etc/postgresql/
# USER serverboards
#CMD sleep 10000
CMD /usr/bin/supervisord
