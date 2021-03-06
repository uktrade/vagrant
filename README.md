# UK Trade Vagrant

UK Trade use Vagrant for tier one development and 12 factor practices. Each project
directory are self-contained environments. In order to use our Vagrant
environments, you will need to install some plugins:

```
$ vagrant plugin install vagrant-dotvm
...
$ vagrant plugin install vagrant-reload
...
```

The vagrant-dotvm plugin extends Vagrant to use YAML for declarative syntax
and extends the command to operate on groups of boxes. For best practices,
each box which is considered a part of the complete estate is marked with the
"all" group. Experimental boxes are not marked with "all".

Currently, the boxes and environment are configured to use Virtualbox and all
boxes are built with the Virtualbox Extension pack. Futher, the configurations
use host-only networks and should be configured accordingly. 
