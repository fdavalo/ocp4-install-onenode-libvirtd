if [[ ! -f $IDIR/install-config.yaml ]]; then
	cat <<EOF > $IDIR/install-config.yaml
apiVersion: v1
baseDomain: ${BASE_DOM}
compute:
- hyperthreading: Disabled
  name: worker
  replicas: 0 
controlPlane:
  hyperthreading: Disabled
  name: master
  replicas: 1 
metadata:
  name: ${CLUSTER_NAME}
networking:
  clusterNetworks:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {}
pullSecret: '${PULL_SEC}'
sshKey: '$(cat $SSH_KEY)'
EOF
	$EDIR/openshift-install-$CLUSTER_OCP_VERSION_MINOR create manifests --dir=./$IDIR
	$EDIR/openshift-install-$CLUSTER_OCP_VERSION_MINOR create ignition-configs --dir=./$IDIR

fi

RAM=1400
sudo virt-install --name ${CLUSTER_NAME}-bootstrap \
  --disk size=50,path=$IMDIR/${CLUSTER_NAME}-bootstrap.qcow2 --ram $RAM --cpu host --vcpus 2 \
  --os-type linux --os-variant rhel7 \
  --network network=$CLUSTER_NAME,model=virtio,mac=$CLUSTER_MAC:02 \
  --noreboot --noautoconsole \
  --location rhcos-install-$CLUSTER_OCP_VERSION_MINOR/ \
  --extra-args "nomodeset rd.neednet=1 coreos.inst=yes coreos.inst.install_dev=vda initrd=http://${HOST_IP}:${WEB_PORT}/rhcos-install-$CLUSTER_OCP_VERSION_MINOR/vmlinuz kernel=http://${HOST_IP}:${WEB_PORT}/rhcos-install-$CLUSTER_OCP_VERSION_MINOR/initramfs.img coreos.inst.ignition_url=http://${HOST_IP}:${WEB_PORT}/$IDIR/bootstrap.ign coreos.live.rootfs_url=http://${HOST_IP}:${WEB_PORT}/rhcos-install-$CLUSTER_OCP_VERSION_MINOR/rootfs.img"

sleep 10
while [[ $(sudo virsh domstate ${CLUSTER_NAME}-bootstrap) == "running" ]]; do sleep 5; done 

RAM=10000
sudo virt-install --name ${CLUSTER_NAME}-master-1 \
  --disk size=50,path=$IMDIR/${CLUSTER_NAME}-master-1.qcow2 --ram $RAM --cpu host --vcpus 4 \
  --os-type linux --os-variant rhel7 \
  --network network=${CLUSTER_NAME},model=virtio,mac=$CLUSTER_MAC:05 \
  --noreboot --noautoconsole \
  --location rhcos-install-$CLUSTER_OCP_VERSION_MINOR/ \
  --extra-args "nomodeset rd.neednet=1 coreos.inst=yes coreos.inst.install_dev=vda initrd=http://${HOST_IP}:${WEB_PORT}/rhcos-install-$CLUSTER_OCP_VERSION_MINOR/vmlinuz kernel=http://${HOST_IP}:${WEB_PORT}/rhcos-install-$CLUSTER_OCP_VERSION_MINOR/initramfs.img coreos.inst.ignition_url=http://${HOST_IP}:${WEB_PORT}/$IDIR/master.ign coreos.live.rootfs_url=http://${HOST_IP}:${WEB_PORT}/rhcos-install-$CLUSTER_OCP_VERSION_MINOR/rootfs.img"

sleep 10
while [[ $(sudo virsh domstate ${CLUSTER_NAME}-master-1) == "running" ]]; do sleep 5; done 

ssh-keygen -R bootstrap.${CLUSTER_NAME}.${BASE_DOM}
ssh-keygen -R $CLUSTER_SUBNET_BASE.2 

ssh-keygen -R master-1.${CLUSTER_NAME}.${BASE_DOM}
ssh-keygen -R $CLUSTER_SUBNET_BASE.5

for x in bootstrap master-1
do
  sudo virsh start ${CLUSTER_NAME}-$x
done

