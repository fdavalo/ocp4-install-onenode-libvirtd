#master-1 boots then needs to get ignition file from bootstrap
#then after booting, master-1 update its image with right coreos image
#then automatically reboot on the right image version
#then starts kubelet (you can check crictl ps to see pods starting)
#etcd will start when operator is ready

#check oc get clusteroperator answers
oc get clusteroperator

#if you want to use only one master
oc patch -n openshift-ingress-operator ingresscontroller/default --patch '{"spec":{"replicas": 1}}' --type=merge
oc scale deployment/etcd-quorum-guard -n openshift-machine-config-operator --replicas=1
oc patch etcd cluster -p='{"spec": {"unsupportedConfigOverrides": {"useUnsupportedUnsafeNonHANonProductionUnstableEtcd": true}}}' --type=merge
oc patch authentications.operator.openshift.io cluster -p='{"spec": {"managementState": "Managed", "unsupportedConfigOverrides": {"useUnsupportedUnsafeNonHANonProductionUnstableOAuthServer": true}}}' --type=merge

#if you want to block temporarily monitoring by setting limitrange too low for now and avoid too much memory needed
oc apply -f limitrange.yml -n openshift-monitoring 
oc apply -f quota.yaml -n openshift-monitoring

#check etcd is available with oc get clusteroperator
oc get clusteroperator 

./openshift-install-$CLUSTER_OCP_VERSION_MINOR --dir=$IDIR wait-for bootstrap-complete

#after, stop bootstrap vm
