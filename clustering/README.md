# Clustering using JMS Plugin
GeoServer supports clustering using JMS cluster plugin or using the ActiveMQ-broker. 

This setup uses the JMS cluster plugin which uses an embedded broker. A docker-compose.yml
is provided in the clustering folder which simulates the replication using 
a shared data directory.

The environment variables associated with replication are listed below
* `CLUSTERING=True` - Specified whether clustering should be activated.
* `BROKER_URL=tcp://0.0.0.0:61661` - This links to the internal broker provided by the JMS cluster plugin.
This value will be different for (Master-Node)
* `READONLY=disabled` - Determines if the GeoServer instance is Read only
* `RANDOMSTRING=87ee2a9b6802b6da_master` - Used to create a unique CLUSTER_CONFIG_DIR for each instance. Not mandatory as the container can self generate this.
* `INSTANCE_STRING=d8a167a4e61b5415ec263` - Used to differentiate cluster instance names. Not mandatory as the container can self generate this.
* `CLUSTER_DURABILITY=false`
* `TOGGLE_MASTER=true` - Differentiates if the instance will be a Master
* `TOGGLE_SLAVE=true` - Differentiates if the instance will be a Node
* `EMBEDDED_BROKER=disabled` - Should be disabled for the Node
* `CLUSTER_CONNECTION_RETRY_COUNT=10` - How many times try to connect to broker
* `CLUSTER_CONNECTION_MAX_WAIT=500` - Wait time between connection to broker retry (in milliseconds)