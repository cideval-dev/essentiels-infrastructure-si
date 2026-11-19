node default {
  # 0. Suppression du depot puppetlabs expire et mise a jour du cache APT
  exec { 'apt-update':
    command => '/bin/rm -f /etc/apt/sources.list.d/puppet*.list && /usr/bin/apt-get update && /usr/bin/touch /var/tmp/.apt-updated',
    creates => '/var/tmp/.apt-updated',
  }

  # 1. Installation des paquets requis
  package { ['nginx', 'curl']:
    ensure  => installed,
    require => Exec['apt-update'],
  }

  # Suppression du virtualhost par defaut d'Ubuntu pour laisser la priorite a default.conf
  file { '/etc/nginx/sites-enabled/default':
    ensure  => absent,
    require => Package['nginx'],
    notify  => Service['nginx'],
  }

  # 2. Gestion du fichier de configuration avec droits stricts
  file { '/etc/nginx/conf.d/default.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package['nginx'],
    notify  => Service['nginx'],
    content => @(EOT),
      server {
          listen 80;
          server_name localhost;

          location / {
              proxy_pass http://websolutions-api:3000;
              proxy_http_version 1.1;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
          }
      }
      | EOT
  }

  # 3. Maintien de l'etat du service Nginx (rechargement a chaud sans coupure)
  service { 'nginx':
    ensure  => running,
    enable  => true,
    restart => '/usr/sbin/nginx -s reload',
    require => Package['nginx'],
  }
}
