# InfluxData Enterprise Docker Installer
Version: 1.0

This will install a full InfluxData Enterprise Cluster on Docker Containers.  The cluster will consist of 3 Metanodes, 2 Datanodes, Chronograf, and a NGINX loadbalancer in front of the datanodes.

![](https://github.com/dp1140a/InfluxdataEntDockerInstaller/blob/master/img/clusterarc.png?raw=true)

### Pre Requisites:
* Docker should be installed.
* A valid Influxdata Enterprise License Key

### Usage:

./cluster.sh [subcommand] [-c file] [-k licenseKey]

### Subcommands:
  * network       create a docker network for the cluster
  * metanodes     create the metanode containers
  * datanodes     create the datanode containers
  * influxdb      create the metanode and datanode containers and create a cluster
  * chronograf    create a chronograf container
  * loadbalancer  create a nginx loadbalancer container
  * all           create all the nodes and create a cluster with a loadbalancer
  * showcluster   displays the current cluster if any
  * stop          Stops the cluster
  * destroy       destroy all containers and erases images
  * config        displays current config
  * usage|help    displays what you are reading right now

### Parameters:
  * -c      name of optional config file to override default values
  * -k      licenseKey

### Config:
INFLUXDB_ENTERPRISE_LICENSE_KEY
+ A valid license key for InfluxData Enterprise.
+ required
+ no default

NETWORK_NAME
+ The name of the docker network to setup for all containers
+ Default: influx-net

META_MASTER_NODE
+ The name of the meta node which should be used as the master node for running commands.
+ Default: meta1

NUM_DATANODES
+ The number fo data nodes to spin up
+ Default: 2

INFLUXDB_VERSION
+ Which version of Influxdb to use.  You should probably update this before you run
+ Default: 1.5.1 <== This will change frequently

CHRONOGRAF_VERSION
+ Which version of Chronograf to use.  You should probably update this before you run
+ Default: 1.4.2.3 <== This will change frequently

LB_NODE_NAME
+ The container name of the loadbalancer.  This will also be the hostname of your connection to influxdb within Chronograf: http://influxdb-lb:8086
+ Default: influxdb-lb

### TODOS:
  * Add Kapacitor Container
  * Add ability to handle license file as well as key
  * Add ability to pull remote Docker image or use local
  * Install Telegraf on all nodes for remote monitoring
