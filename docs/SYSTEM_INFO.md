# Fenway System Information

Extracted: Sun Apr 19 22:51:31 EDT 2026

## System Details

```
Linux fenway 6.14.0-37-generic #37~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Thu Nov 20 10:25:38 UTC 2 x86_64 x86_64 x86_64 GNU/Linux
```

## Docker Version

```
Client: Docker Engine - Community
 Version:           29.1.3
 API version:       1.52
 Go version:        go1.25.5
 Git commit:        f52814d
 Built:             Fri Dec 12 14:49:32 2025
 OS/Arch:           linux/amd64
 Context:           default

Server: Docker Engine - Community
 Engine:
  Version:          29.1.3
  API version:      1.52 (minimum version 1.44)
  Go version:       go1.25.5
  Git commit:       fbf3ed2
  Built:            Fri Dec 12 14:49:32 2025
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          v2.2.1
  GitCommit:        dea7da592f5d1d2b7755e3a161be07f43fad8f75
 runc:
  Version:          1.3.4
  GitCommit:        v1.3.4-0-gd6d73eb8
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0
```

## Disk Usage

```
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              2.0G  4.9M  2.0G   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv  466G   44G  399G  10% /
tmpfs                              9.7G     0  9.7G   0% /dev/shm
tmpfs                              5.0M   12K  5.0M   1% /run/lock
efivarfs                           128K   43K   81K  35% /sys/firmware/efi/efivars
/dev/nvme0n1p2                     2.0G  214M  1.6G  12% /boot
/dev/nvme0n1p1                     1.1G  6.2M  1.1G   1% /boot/efi
tmpfs                              2.0G   96K  2.0G   1% /run/user/120
//omnium-gatherum/Archive           18T   15T  2.7T  85% /mnt/omnium-archive
//omnium-gatherum/fenway-backups    18T   15T  2.7T  85% /mnt/fenway-backups
tmpfs                              2.0G   84K  2.0G   1% /run/user/1001
```

## Running Containers

```
NAMES                 IMAGE                                  STATUS                  PORTS
ghost                 ghost:latest                           Up 9 days               2368/tcp
ghost-db              mysql:8.0                              Up 7 weeks (healthy)    3306/tcp, 33060/tcp
players-scheduler-1   ghcr.io/jamiepinkham/players:main      Up 2 months             3000/tcp
players-players-1     ghcr.io/jamiepinkham/players:main      Up 2 months             0.0.0.0:3000->3000/tcp, [::]:3000->3000/tcp
players-db-1          postgres:16                            Up 2 months (healthy)   5432/tcp
cloudflared-tunnel    cloudflare/cloudflared:latest          Up 2 months             
sabnzbd               lscr.io/linuxserver/sabnzbd            Up 2 months             0.0.0.0:1337->8080/tcp, [::]:1337->8080/tcp
radarr                lscr.io/linuxserver/radarr             Up 2 months             0.0.0.0:7878->7878/tcp, [::]:7878->7878/tcp
transmission          lscr.io/linuxserver/transmission       Up 2 months             0.0.0.0:9091->9091/tcp, [::]:9091->9091/tcp, 0.0.0.0:51413->51413/tcp, [::]:51413->51413/tcp, 0.0.0.0:51413->51413/udp, [::]:51413->51413/udp
overseerr             lscr.io/linuxserver/overseerr:latest   Up 2 months             0.0.0.0:5055->5055/tcp, [::]:5055->5055/tcp
sonarr                lscr.io/linuxserver/sonarr             Up 2 months             0.0.0.0:8989->8989/tcp, [::]:8989->8989/tcp
prowlarr              lscr.io/linuxserver/prowlarr:latest    Up 2 months             0.0.0.0:9696->9696/tcp, [::]:9696->9696/tcp
caddy                 caddy:latest                           Up 3 months             0.0.0.0:80->80/tcp, [::]:80->80/tcp, 0.0.0.0:443->443/tcp, [::]:443->443/tcp, 0.0.0.0:2019->2019/tcp, [::]:2019->2019/tcp, 443/udp
portainer             portainer/portainer-ce:latest          Up 3 months             8000/tcp, 9443/tcp, 0.0.0.0:9000->9000/tcp, [::]:9000->9000/tcp
```
