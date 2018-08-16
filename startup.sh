#!/bin/sh

IPEXTERNO=$(curl www.meuip.com.br | grep IP: | awk '{print $9}' | sed 's/<\/p>//g')
yum install puppet -y

echo "criando module puppet"
mkdir -p /usr/share/puppet/modules/testedevops && mkdir -p /usr/share/puppet/modules/testedevops/{manifests,files,templates}

echo "criando manifests"
cat <<EOF > /usr/share/puppet/modules/testedevops/manifests/init.pp
class testedevops {
    include testedevops::test
}
EOF


echo "add test.pp"

cat <<EOF > /usr/share/puppet/modules/testedevops/manifests/test.pp
class testedevops::test {

    package { ['nmap','yum-utils','device-mapper-persistent-data','lvm2','docker','git']:
       ensure => present
    }

    service { 'docker':
       name  => 'docker',
       ensure => 'running',
       require => Package['docker'],
    }

    service { 'haproxy':
       name  => 'haproxy',
       ensure => 'running',
       require => Package['haproxy'],
    }

    package { 'haproxy':
       ensure => latest
    }

    file { 'haproxy.cfg':
       path   => '/etc/haproxy/haproxy.cfg',
       owner  => 'root',
       group  => 'root',
       content => template('testedevops/haproxy.erb'),
       require => Package['haproxy'],
    }

    file { 'teste.yml': 
       path   => '/tmp/teste.yml',
       owner  => 'root',
       group  => 'root',
       content => template('testedevops/teste.erb'),
   }

}
EOF


echo "criando conf teste de carga"
cat <<EOF > /usr/share/puppet/modules/testedevops/templates/teste.erb
execution:
- concurrency: 10
  ramp-up: 15s
  hold-for: 30s
  scenario: teste-carga

scenarios:
  teste-carga:
    requests:
    - http://hello.teste.rafael/
EOF


echo "adicionando template haproxy"
cat <<EOF > /usr/share/puppet/modules/testedevops/templates/haproxy.erb
# config for haproxy 1.5.x

global
        log 127.0.0.1   local0
        log 127.0.0.1   local1 notice
        maxconn 4096
        user haproxy
        group haproxy
        daemon

defaults
        log     global
        mode    http
        option  httplog
        option  dontlognull
        option forwardfor
        option http-server-close
        stats enable
        stats auth administrator:admin123
        stats uri /haproxyStats

frontend http-in
        bind *:80
        log         127.0.0.1    local6
        option httplog

        # Define hosts
        acl host_nodejs hdr(host) -i hello.teste.rafael

        ## figure out which one to use
        use_backend servers_nodejs if host_nodejs

backend servers_nodejs
        balance leastconn
        option httpclose
        option forwardfor
        cookie JSESSIONID prefix
        server node1 localhost:3000 cookie A check
EOF


echo "log haproxy"
cat <<EOF > /etc/rsyslog.d/haproxy.conf
$ModLoad imudp
$UDPServerAddress 127.0.0.1
$UDPServerRun 514
local6.* /var/log/haproxy.log
EOF

/etc/init.d/rsyslog restart

echo "criando script de monitoramento"

cat <<EOF > /checkrequest.sh
#!/bin/bash

REQUESTSOK=$(cat /var/log/haproxy.log | awk '{ print $11}' | grep 200 | wc -l)
REQUESTSNOK=$(cat /var/log/haproxy.log | awk '{ print $11}' | grep 500| wc -l)
REQUESTSNULL=$(cat /var/log/haproxy.log | awk '{ print $11}' | grep 400| wc -l)

echo "requests HTTP 200 = $REQUESTSOK"
echo "requests HTTP 500 = $REQUESTSNOK"
echo "requests HTTP 400 = $REQUESTSNULL"
EOF

chmod 777 /checkrequest.sh

cat <<EOF > /monitoring.sh
#!/bin/bash
docker ps | grep "node-application"

if [ $? -eq 0 ]; then
    echo APP node no ar
else
    echo "APP node Down , reiniciando."
    docker run -p 3000:3000 node-application
fi
EOF

echo "criando crontab"
echo "*/2 * * * *  bash /monitoring.sh" > /var/spool/cron/root
echo "*/3 * * * *  docker run -it --rm -v /tmp:/bzt-configs -v /etc/hosts:/etc/hosts blazemeter/taurus teste.yml > /testecarga.log" >> /var/spool/cron/root
echo "0 12 * * *  bash /checkrequest.sh " >> /var/spool/cron/root

echo "add entrada no hosts"
echo "$IPEXTERNO   hello.teste.rafael" > /etc/hosts

puppet apply -e 'include testedevops::test'

echo "clonando repo da aplicacao"
cd / && git clone https://github.com/rafaelsilvaa10/nodejs-app.git
cd /nodejs-app

docker build . -t node-application

echo "iniciano app"
docker run -p 3000:3000 node-application 
