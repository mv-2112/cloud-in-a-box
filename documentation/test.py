from diagrams import Cluster, Diagram
from diagrams.k8s.compute import Pod, StatefulSet
from diagrams.k8s.network import Service
from diagrams.k8s.storage import PV, PVC, StorageClass
from diagrams.openstack.compute import Nova
from diagrams.openstack.networking import Octavia, Neutron
from diagrams.openstack.orchestration import Heat
from diagrams.openstack.sharedservices import Keystone, Glance, Barbican
from diagrams.openstack.storage import Cinder
from diagrams.openstack.workloadprovisioning import Magnum
from diagrams.onprem.ci import Jenkins
from diagrams.generic.os import Ubuntu
from diagrams.generic.storage import Storage
from diagrams.generic.compute import Rack
from diagrams.onprem.storage import Ceph



with Diagram("Cloud-in-a-Box overall architecture", show=False):
    with Cluster("Machine"):
        machine = Rack("HP z640")

        with Cluster("Disks"):
            boot_disk = Storage("OS on nvme0")
            ceph_disks = []
            ceph_disks.append(Storage("Ceph vol on ssd0"))
            ceph_disks.append(Storage("Ceph vol on ssd1"))
            ceph_disks.append(Storage("Ceph vol on ssd2"))
            ceph_disks.append(Storage("Ceph vol on ssd3"))

        with Cluster("OS"):
            os = Ubuntu("Ubuntu 24.04 LTS")



            with Cluster("Sunbeam"):
                services = []
                services.append(Ceph("Ceph"))
                services.append(Octavia("Load Balancer"))
                services.append(Nova("Computer"))
                services.append(Neutron("OVN Networking"))
                services.append(Heat("Orchestration"))
                services.append(Cinder("Block Storage"))

                magnum = Magnum("Magnum Container Orchestration")

                services[4] << magnum
                services[5] >> services[0]


                with Cluster("Kubernetes"):
                    with Cluster("Jenkins"):
                        svc = Service("svc")
                        sts = StatefulSet("sts")

                        apps = []
                        pod = Pod("pod")
                        pvc = PVC("pvc")
                        pod - sts - pvc
                        apps.append(svc >> pod >> pvc)

                    apps << PV("pv") << StorageClass("sc") << services[5]

            magnum << apps
            machine << ceph_disks >> services[0]
            machine << boot_disk >> os

