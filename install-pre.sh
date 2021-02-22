#!/bin/bash

cd $ODIR

mkdir -p rhcos-install-$CLUSTER_OCP_VERSION_MINOR
if [[ ! -f rhcos-install-$CLUSTER_OCP_VERSION_MINOR/vmlinuz ]]; then
	wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/$CLUSTER_OCP_VERSION/$CLUSTER_OCP_VERSION_MINOR/rhcos-live-kernel-x86_64 -O rhcos-install-$CLUSTER_OCP_VERSION_MINOR/vmlinuz
fi
if [[ ! -f rhcos-install-$CLUSTER_OCP_VERSION_MINOR/initramfs.img ]]; then
	wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/$CLUSTER_OCP_VERSION/$CLUSTER_OCP_VERSION_MINOR/rhcos-live-initramfs.x86_64.img -O rhcos-install-$CLUSTER_OCP_VERSION_MINOR/initramfs.img
fi
if [[ ! -f rhcos-install-$CLUSTER_OCP_VERSION_MINOR/rootfs.img ]]; then
	wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/$CLUSTER_OCP_VERSION/$CLUSTER_OCP_VERSION_MINOR/rhcos-live-rootfs.x86_64.img -O rhcos-install-$CLUSTER_OCP_VERSION_MINOR/rootfs.img
fi
if [[ ! -f rhcos-install-$CLUSTER_OCP_VERSION_MINOR/.treeinfo ]]; then
	cat <<EOF > rhcos-install-$CLUSTER_OCP_VERSION_MINOR/.treeinfo
[general]
arch = x86_64
family = Red Hat CoreOS
platforms = x86_64
version = $CLUSTER_OCP_VERSION_MINOR
[images-x86_64]
initrd = initramfs.img
kernel = vmlinuz
EOF
fi

if [[ ! -f $EDIR/openshift-install-$CLUSTER_OCP_VERSION_MINOR ]]; then
	wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$CLUSTER_OCP_VERSION_MINOR/openshift-install-linux-$CLUSTER_OCP_VERSION_MINOR.tar.gz
	tar xf openshift-install-linux-$CLUSTER_OCP_VERSION_MINOR.tar.gz openshift-install
	mv openshift-install $EDIR/openshift-install-$CLUSTER_OCP_VERSION_MINOR
fi

if [[ ! -f $EDIR/oc-$CLUSTER_OCP_VERSION_MINOR ]]; then
	wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$CLUSTER_OCP_VERSION_MINOR/openshift-client-linux-$CLUSTER_OCP_VERSION_MINOR.tar.gz
	tar xf openshift-client-linux-$CLUSTER_OCP_VERSION_MINOR.tar.gz oc
	mv oc $EDIR/oc-$CLUSTER_OCP_VERSION_MINOR
fi
	
mkdir -p $IDIR

sudo virsh net-info $CLUSTER_NAME 
ret=$?

if [[ $ret -ne 0 ]]; then
	cat <<EOF > $IDIR/$CLUSTER_NAME.xml
<network xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0'>
  <name>$CLUSTER_NAME</name>
  <domain name='$CLUSTER_NAME.$BASE_DOM' localOnly='no'/>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='$CLUSTER_NAME' stp='on' delay='0'/>
  <dns>
    <srv service='etcd-server-ssl' protocol='tcp' domain='$CLUSTER_NAME.$BASE_DOM' target='etcd-0.$CLUSTER_NAME.$BASE_DOM' port='2380' weight='10'/>
    <host ip='$CLUSTER_SUBNET_BASE.2'>
      <hostname>bootstrap.$CLUSTER_NAME.$BASE_DOM</hostname>
    </host>
    <host ip='$CLUSTER_SUBNET_BASE.3'>
      <hostname>lb.$CLUSTER_NAME.$BASE_DOM</hostname>
    </host>
    <host ip='$CLUSTER_SUBNET_BASE.5'>
      <hostname>master-1.$CLUSTER_NAME.$BASE_DOM</hostname>
    </host>
    <host ip='$CLUSTER_SUBNET_BASE.8'>
      <hostname>worker-1.$CLUSTER_NAME.$BASE_DOM</hostname>
    </host>
  </dns>
  <ip address='$CLUSTER_SUBNET_BASE.1' netmask='$CLUSTER_SUBNET_NETMASK'>
    <dhcp>
      <range start='$CLUSTER_SUBNET_BASE.2' end='$CLUSTER_SUBNET_BASE.254' />
      <host mac='$CLUSTER_MAC:02' ip='$CLUSTER_SUBNET_BASE.2' name='bootstrap.$CLUSTER_NAME.$BASE_DOM'/>
      <host mac='$CLUSTER_MAC:03' ip='$CLUSTER_SUBNET_BASE.3' name='lb.$CLUSTER_NAME.$BASE_DOM'/>
      <host mac='$CLUSTER_MAC:05' ip='$CLUSTER_SUBNET_BASE.5' name='master-1.$CLUSTER_NAME.$BASE_DOM'/>
      <host mac='$CLUSTER_MAC:08' ip='$CLUSTER_SUBNET_BASE.8' name='worker-1.$CLUSTER_NAME.$BASE_DOM'/>
    </dhcp>
  </ip>
  <dnsmasq:options>
	<dnsmasq:option value='address=/apps.${CLUSTER_NAME}.${BASE_DOM}/$CLUSTER_SUBNET_BASE.3'></dnsmasq:option>
  </dnsmasq:options>
</network>
EOF

	sudo virsh net-define $IDIR/$CLUSTER_NAME.xml
	sudo virsh net-autostart $CLUSTER_NAME 
	sudo virsh net-start $CLUSTER_NAME 
fi

nohup python3 -m http.server $WEB_PORT &

#iptables -I INPUT <number before reject> -p tcp -m tcp --dport ${WEB_PORT} -s ${HOST_IP} -j ACCEPT

if [[ ! -f $IMDIR/${CLUSTER_NAME}-lb.qcow2 ]]; then
	mkdir -p $IMDIR
	if [[ ! -f $ODIR/rhel-server-7.7-x86_64-kvm.qcow2 ]]; then
		echo "download RHEL 7.x KVM image"
		echo "rename to rhel-server-7-x86_64-kvm.qcow2"
		exit 1
	fi
	sudo cp $ODIR/rhel-server-7-x86_64-kvm.qcow2 $IMDIR/${CLUSTER_NAME}-lb.qcow2
fi

grep -v "$CLUSTER_SUBNET_BASE." /etc/hosts | grep -v "${CLUSTER_NAME}.${BASE_DOM}" > $IDIR/hosts
echo "$CLUSTER_SUBNET_BASE.2 bootstrap.${CLUSTER_NAME}.${BASE_DOM}" >> $IDIR/hosts

i=1
echo "$CLUSTER_SUBNET_BASE.5 master-$((i)).${CLUSTER_NAME}.${BASE_DOM} etcd-$((i-1)).${CLUSTER_NAME}.${BASE_DOM}" >> $IDIR/hosts
echo "srv-host=_etcd-server-ssl._tcp.${CLUSTER_NAME}.${BASE_DOM},etcd-$((i-1)).${CLUSTER_NAME}.${BASE_DOM},2380,0,10" > $IDIR/${CLUSTER_NAME}.conf

i=1
echo "$CLUSTER_SUBNET_BASE.8 worker-${i}.${CLUSTER_NAME}.${BASE_DOM}" >> $IDIR/hosts

echo "$CLUSTER_SUBNET_BASE.3 lb.${CLUSTER_NAME}.${BASE_DOM} api.${CLUSTER_NAME}.${BASE_DOM} api-int.${CLUSTER_NAME}.${BASE_DOM} oauth-openshift.apps.${CLUSTER_NAME}.${BASE_DOM}" >> $IDIR/hosts
echo "address=/apps.${CLUSTER_NAME}.${BASE_DOM}/$CLUSTER_SUBNET_BASE.3" >> $IDIR/${CLUSTER_NAME}.conf

sudo cp /etc/hosts $IDIR/hosts.save
sudo cp $IDIR/hosts /etc/hosts
sudo cp $IDIR/${CLUSTER_NAME}.conf ${DNS_DIR}/${CLUSTER_NAME}.conf

sudo systemctl reload NetworkManager
sudo systemctl restart libvirtd

