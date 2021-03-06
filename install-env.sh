#directory where are installation files
export ODIR=... ex: /home/me/ocp4
export BASE_DOM=... ex: cluster
export CLUSTER_OCTET=... ex: 198
export SSH_KEY=... ex: /home/me/.ssh/id_rsa.pub
export PULL_SEC=... ex: $(cat $ODIR/crc-pull-secret)
export RHNUSER=... ex: me@redhat.com

export CLUSTER_OCP_VERSION=4.6
export CLUSTER_OCP_VERSION_MINOR=4.6.8

#pass password as parameter
export RHNPASS=$1

#generated variables
export CLUSTER_NAME=ocp4-$CLUSTER_OCTET

export EDIR=$ODIR
export PATH=$PATH:$ODIR

#host to guests isolated network
export WEB_PORT=8080
export DNS_DIR="/etc/NetworkManager/dnsmasq.d"

export CLUSTER_SUBNET=192.168.$CLUSTER_OCTET.0
export CLUSTER_SUBNET_BASE=`echo $CLUSTER_SUBNET | awk -F\. '{print $1"."$2"."$3;}'`
export CLUSTER_SUBNET_NETMASK=255.255.255.0
export CLUSTER_MAC=52:$(echo $CLUSTER_OCTET | od -x | awk '{print substr($2,1,2)":"substr($2,3,2)":"substr($3,1,2)":"substr($3,3,2);}' | head -1)
export HOST_IP=192.168.$CLUSTER_OCTET.1

export IDIR=install_dir_$CLUSTER_NAME
export IMDIR=$IDIR/images
export INSTALL_MODE=minimal

export KUBECONFIG=$ODIR/$IDIR/auth/kubeconfig
alias oc=oc-$CLUSTER_OCP_VERSION_MINOR
