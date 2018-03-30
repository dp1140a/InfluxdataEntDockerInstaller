#!/bin/bash
CONFIG_FILE="cluster.conf"
INFLUXDB_ENTERPRISE_LICENSE_KEY=""
NETWORK_NAME=influx-net
META_MASTER_NODE=meta1
NUM_DATANODES=2

INFLUXDB_VERSION=1.5.1
CHRONOGRAF_VERSION=1.4.2.3

METANODE_DOCKER_TAG=$INFLUXDB_VERSION-meta-alpine
DATANODE_DOCKER_TAG=$INFLUXDB_VERSION-data-alpine
CHRONOGRAF_DOCKER_TAG=$CHRONOGRAF_VERSION-alpine

LB_NODE_NAME=influxdb-lb

## Create Influx Network ##
function network(){
  if [ ! "$(docker network ls | grep $NETWORK_NAME)" ]; then
    echo -e "Creating Influx Network"
    docker network create --driver bridge $NETWORK_NAME
  else
    echo "$NETWORK_NAME network exists."
  fi
  docker network inspect influx-net
}

## Create Meta Nodes ##
function metanodes(){
  network
  checkkey
  echo -e "\nCreating Meta Nodes"

  echo -e "Checking for Meta Node Docker Image: influxdb:$METANODE_DOCKER_TAG"
  if [[ "$(docker images -q influxdb:"$METANODE_DOCKER_TAG" 2> /dev/null)" == "" ]];
  then
    echo "No Docker Image Found.  Pulling.";
    docker pull influxdb:$METANODE_DOCKER_TAG
    echo -e "Image Pulled"
  else
    echo -e "InfluxDB Meta Image found."
  fi;

  for I in {1..3};
  do
    if [ "$(docker ps -aq -f status=exited -f name=meta$I)" ]; then
      # cleanup
      echo "Found existing container for meta$I.  Restarting."
      docker restart meta$I
    else
      echo "No container found for meta$I. Creating container meta$I."
      # run your container
      docker run --env INFLUXDB_ENTERPRISE_LICENSE_KEY=$INFLUXDB_ENTERPRISE_LICENSE_KEY --network influx-net --hostname meta$I --name meta$I -d influxdb:$METANODE_DOCKER_TAG
    fi
  done

  echo -e "Adding Meta Nodes to Cluster"
  for I in {1..3};
  do
    echo "Adding node meta$I";
    docker exec -it $META_MASTER_NODE bash -c '/usr/bin/influxd-ctl add-meta meta'$I':8091'
    wait
  done
}

## Create Data Nodes ##
function datanodes(){
  network
  checkkey
  echo -e "\nCreating Data Nodes"
  echo -e "Checking for Data Node Docker Image: influxdb:$DATANODE_DOCKER_TAG"
  if [[ "$(docker images -q influxdb:"$DATANODE_DOCKER_TAG" 2> /dev/null)" == "" ]];
  then
    echo "No Docker Image Found.  Pulling.";
    #cd influxdb/data
    #docker build -t influxdb:$DATANODE_DOCKER_TAG .
    #cd ../..
    docker pull influxdb:$DATANODE_DOCKER_TAG
    echo -e "Image Pulled"
  else
    echo -e "Meta Image found."
  fi;

  for I in $(seq 1 $NUM_DATANODES);
  do
    if [ "$(docker ps -aq -f status=exited -f name=data$I)" ]; then
      # cleanup
      echo "Found existing container for data$I.  Restarting."
      docker restart data$I
    else
      echo "No container found for data$I. Creating container data$I."
      # run your container
      docker run --env INFLUXDB_ENTERPRISE_LICENSE_KEY=$INFLUXDB_ENTERPRISE_LICENSE_KEY --network influx-net --hostname data$I --name data$I -d influxdb:$DATANODE_DOCKER_TAG
    fi
  done

  echo -e "Adding Data Nodes to Cluster"
  for I in $(seq 1 $NUM_DATANODES);
  do
    echo "Adding node data$I";
    docker exec -it $META_MASTER_NODE bash -c '/usr/bin/influxd-ctl add-data data'$I':8088'
    wait
  done
}

function influxdb(){
  metanodes
  datanodes
  echo -e "Waiting 5 seconds"
  sleep 5
  docker exec -it $META_MASTER_NODE bash -c '/usr/bin/influxd-ctl show'
}

## Create Kapacitor Node ##
function kapacitornode(){
  echo -e "\nNot Implemented Yet"

}

## Create Chronograf Node ##
function chronografnode(){
  echo -e "\nCreating Chronograf Node"
  echo -e "Checking for Chronograf Node Docker Image: chronograf:$CHRONOGRAF_DOCKER_TAG"
  if [[ "$(docker images -q chronograf:"$CHRONOGRAF_DOCKER_TAG" 2> /dev/null)" == "" ]];
  then
    echo "No Docker Image Found.  Pulling.";
    #cd chronograf
    #docker build -t chronograf:$CHRONOGRAF_DOCKER_TAG .
    #cd ..
    docker pull chronograf:$CHRONOGRAF_DOCKER_TAG
    echo -e "Image Pulled"
  else
    echo -e "Chronograf Image found."
  fi;

  echo "Creating chronograf";
  docker run --network influx-net --hostname chronograf --name chronograf -p 8888:8888 -d chronograf:$CHRONOGRAF_DOCKER_TAG
}

function loadbalancer(){
  if [[ "$(docker images -q nginx:alpine 2> /dev/null)" == "" ]];
  then
    echo "No Docker Image Found.  Pulling.";
    #cd nginx
    #docker build -t influxdb-nginx:latest .
    #cd ..
    docker pull nginx:alpine
    echo -e "Image Created"
  else
    echo -e "NGINX Image found."
  fi;

  if [ "$(docker ps -aq -f status=exited -f name=$LB_NODE_NAME)" ]; then
    # cleanup
    echo "Found existing container for nginx.  Restarting."
    docker restart $LB_NODE_NAME
  else
    echo "No container found for $LB_NODE_NAME. Creating container $LB_NODE_NAME."
    # run your container
    docker run --network influx-net --hostname $LB_NODE_NAME --name $LB_NODE_NAME -p 8086:8086 -v $(pwd)/nginx/nginx.conf:/etc/nginx/nginx.conf:ro -d nginx:alpine
  fi

}

function showcluster(){
  docker exec -it $META_MASTER_NODE bash -c 'influxd-ctl show'
}

## Stop Cluster ##
function stop(){
  echo -e "\nStoppping"
  ## Load Balancer and Chronograf ##
  docker stop $LB_NODE_NAME chronograf

  ## Data Nodes ##
  for I in $(seq 1 $NUM_DATANODES);
  do
    docker stop data$I
  done

  ## Meta Nodes ##
  for I in {1..3};
  do
    docker stop meta$I
  done
}

function rm(){
  echo -e "\nRemoving Containers"
  ## Load Balancer and Chronograf ##
  docker rm $LB_NODE_NAME chronograf

  ## Data Nodes ##
  for I in $(seq 1 $NUM_DATANODES);
  do
    docker rm data$I
  done

  ## Meta Nodes ##
  for I in {1..3};
  do
    docker rm meta$I
  done
}

function rmi(){
  echo -e "\nRemoving Images"
  docker rmi influxdb:$METANODE_DOCKER_TAG influxdb:$DATANODE_DOCKER_TAG chronograf:$CHRONOGRAF_DOCKER_TAG nginx:alpine
}

## Cleanup Everything ##
function destroy(){
  stop
  rm
  rmi
  echo -e "\nRemoving Network"
  docker network rm influx-net
}

function checkkey(){
  if [ -z $INFLUXDB_ENTERPRISE_LICENSE_KEY ]
  then
    echo -e " "
    echo -e "You must provide a License Key with either the -k flag or in a config file"
    exit 1
  fi
}

function config(){
  ( set -o posix ; set ) | grep 'CONFIG_FILE\|INFLUXDB_ENTERPRISE_LICENSE_KEY\|NETWORK_NAME\|META_MASTER_NODE\|NUM_DATANODES\|INFLUXDB_VERSION\|CHRONOGRAF_VERSION\|DOCKER_REPO\|LB_NODE_NAME\|INFLUXDB_META_TAG\|INFLUXDB_DATA_TAG'
  exit 0
}

function usage(){
  echo "cluster.sh will create a cluster of InfluxDB Enterprise on Docker."
  echo "Usage: $0 [subcommand] [-c file] [-k licenseKey]"
  echo " "
  echo "Subcommands:"
  echo "  network       create a docker network for the cluster"
  echo "  metanodes     create the metanode containers"
  echo "  datanodes     create the datanode containers"
  echo "  influxdb      create the metanode and datanode containers and create a cluster"
  echo "  chronograf    create a chronograf container"
  echo "  loadbalancer  create a nginx loadbalancer container"
  echo "  all           create all the nodes and create a cluster with a loadbalancer"
  echo "  showcluster   displays the current cluster if any"
  echo "  Stop          Stops the cluster"
  echo "  destroy       destroy all containers and erases images"
  echo "  config        displays current config"
  echo "  usage|help    displays what you are reading right now"
  echo " "
  echo "Parameters:"
  echo "  -c      name of optional config file to override default values"
  echo "  -k      licenseKey"
  echo " "
  echo "TODOS:"
  echo "  Add Kapacitor Container"
  echo "  Add ability to handle license file as well as key"
  echo "  Add ability to pull remote Docker image or use local"
  exit 0
}

subcommand=$1
shift
while getopts ":k:c:" opt; do
  case ${opt} in
    c)
      CONFIG_FILE=$OPTARG
      if [[ ! -f $CONFIG_FILE ]];
      then
        echo -f "$CONFIG_FILE not found"
        exit 1
      else
        echo -e "Using Config File $CONFIG_FILE"
      fi
      ;;
    k)
      INFLUXDB_ENTERPRISE_LICENSE_KEY=$OPTARG
      ;;
    \?)
      echo "Invalid Option: $OPTARG" 1>&2
      usage
      ;;
  esac
done
shift $((OPTIND -1))
source $CONFIG_FILE

case $subcommand in
  network)
    network
    ;;

  metanodes)
    metanodes
    ;;

  datanodes)
    datanodes
    ;;

  influxdb)
    influxdb
    ;;

  chronograf)
    chronografnode
    ;;

  loadbalancer)
    loadbalancer
    ;;

  all)
    network
    influxdb
    loadbalancer
    chronografnode
    ;;

  showcluster)
    showcluster
    ;;

  stop)
    stop;
    ;;

  destroy)
    destroy
    ;;

  config)
    config
    ;;

  help)
    usage
    ;;

  usage)
    usage
    ;;

  *)
    usage
    ;;
esac
