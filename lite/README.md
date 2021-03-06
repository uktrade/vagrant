# BIS Vagrant

LITE primarily use the Kubernetes project. It's definitions are in projects/kubernetes.

## Red Hat Subscription

In order to use the environment, you will need to create a file in the variables
directory with two variables that authenticate you to Red Hat Enterprise Linux
Developer Suite. 

https://www.redhat.com/apps/store/developers/rhel_developer_suite.html

You must be subscribed to this product. Also, you will need to
obtain a valid RHEL7 Vagrant box. In the projects/kubernetes/variables/network.yaml
file, the box is defined as jhcook/rhel7.

Git is instructed to ignore the variables/personal.yaml in the variables/.gitignore
file.

```
$ cat variables/personal.yaml
---

rh_username: "justin@blabla.com"
rh_password: "somePassword"

$ cat variables/.gitignore
personal.yaml
```

## Adding the box

Once you have obtained a valid RHEL7 box, please add it to the Vagrant cache.

```
$ vagrant box add --name <box_name> ./path/to/rhel7.box
```

## Preparing Vagrant

There are plugins that are necessary to install in Vagrant in order to
properly use the RHEL7 boxes. 

```
$ vagrant plugin list
vagrant-dotvm (0.39.0)
  - Version Constraint: > 0
vagrant-registration (1.3.1)
  - Version Constraint: > 0
vagrant-reload (0.0.1)
  - Version Constraint: > 0
vagrant-service-manager (1.5.0)
  - Version Constraint: > 0
vagrant-share (1.1.6)
  - Version Constraint: > 0
vagrant-sshfs (1.3.0)
  - Version Constraint: > 0
```

## Preparing VirtualBox

VirtualBox should have the extensions installed and a host-only network needs
to be created. Enter VirtualBox > Preferences, select teh Network menu and then
Host-only Networks. Create a new network named vboxnet0 with the following:

-  IPv4 Address: 10.100.0.254
-  IPv4 Network Mask: 255.255.0.0
-  Disable DHCP Server

## Usage

By default, commands are directed toward the IPA master box. Therefore,
Vagrant ssh access does not need to be specified to the master.

```
$ vagrant group up mgmt
...
$ ansible-playbook -u vagrant -i hosts/uktrade -l uktrade-mgmt-ipa,uktrade-mgmt-openshift uktrade-platforms.yaml
...
$ ansible-playbook -u vagrant -i hosts/uktrade -l uktrade-mgmt-ipa uktrade-ipaserver.yaml
...
$ ansible-playbook -u vagrant -i hosts/uktrade-mgmt-openshift uktrade-openshift.yaml
```

Once you have created the environment, you will notice Kubernetes functions as
a three-node cluster.

```
[root@uktrademom01 ~]# oc get nodes
NAME                                              STATUS    AGE
uktrademom01.licensing.service.trade.gov.uk.test   Ready     17m
uktrademon01.licensing.service.trade.gov.uk.test   Ready     11m
uktrademon02.licensing.service.trade.gov.uk.test   Ready     11m
```
