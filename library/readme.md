# Ansible modules

This folder consists for Ansible modules that can be used in playbooks

## Installation

Download it and place it in your Ansible library :)


## Modules

### win_cluster
This module is responsible for managing Windows failover clusters.

#### Invocation 
```ansible
- name: 'Manage cluster {{ cluster_name }} - action {{ cluster_action }}'
  win_cluster:
    action: '{{ cluster_action }}'
    cluster_name: '{{ cluster_name }}'
    cluster_group: '{{ cluster_group }}'
    waittime_seconds: '{{ waittime_seconds }}' 
```

#### Parameters:
#### action
Parameter specifies available actions (get, suspend_node, resume_node)

##### cluster_name
Cluster name as from Get-Cluster cmdlet 

##### cluster_group
Cluster group that specifies clustered roles in failover cluster

##### waittime_seconds
Time in seconds that specifies what time will script wait for a resources to be moved before any action

#### Actions
##### get
Gets a status data - cluster name, domain, id and shared volumes root. 
##### suspend_node
Moves resource group to another node if machine is active node in cluster, stops connected service and suspends node
##### resume_node
Moves resource group to current node and resumes node


## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.


## License
[MIT](https://choosealicense.com/licenses/mit/)
