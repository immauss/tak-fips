

docker build -t ca-setup-hardened --build-arg ARG_CA_NAME=CA --build-arg ARG_STATE=WA --build-arg ARG_CITY=Wiesbaden --build-arg ARG_ORGANIZATIONAL_UNIT=USAREURAF -f docker/Dockerfile.ca .

docker run --name ca-setup-hardened -it -d ca-setup-hardened

echo "Sleeping for 60 seconds to allow CA to generate certs"
sleep 60

echo "Copying certs to local filesystem"
docker cp ca-setup-hardened:/tak/certs/files files 

echo "Copying certs to tak folder for build"  
[ -d tak/certs/files ] || mkdir tak/certs/files \
&& docker cp ca-setup-hardened:/tak/certs/files/takserver.jks tak/certs/files/ \
&& docker cp ca-setup-hardened:/tak/certs/files/truststore-root.jks tak/certs/files/ \
&& docker cp ca-setup-hardened:/tak/certs/files/fed-truststore.jks tak/certs/files/ \
&& docker cp ca-setup-hardened:/tak/certs/files/admin.pem tak/certs/files/ \
&& docker cp ca-setup-hardened:/tak/certs/files/config-takserver.cfg tak/certs/files/

echo "Creating network"
docker network create takserver-net --subnet=172.28.0.0/16

echo "Building takserver-hardened database"
docker build -t tak-database-hardened -f docker/Dockerfile.hardened-takserver-db . 

echo "Building takserver-hardened"
docker build -t takserver-hardened -f docker/Dockerfile.hardened-takserver .

echo "Starting database container"
docker run --name tak-database-hardened --network takserver-net -d tak-database-hardened -p 5432:5432

echo "Starting takserver-hardened"
docker run --name takserver-hardened --network takserver-net -p 8089:8089 -p 8443:8443 -p 8444:8444 -p 8446:8446 -t -d takserver-hardened

echo "Generating admin cert fingerprint"
FPrint=$(docker exec -it ca-setup-hardened bash -c "openssl x509 -noout -fingerprint -md5 -inform pem -in files/admin.pem | grep -oP 'MD5 Fingerprint=\K.*'")
echo "Admin cert fingerprint: $FPrint"

echo "Copying admin cert fingerprint to takserver-hardened"
docker exec -it takserver-hardened bash -c 'java -jar /opt/tak/utils/UserManager.jar usermod -A -f $FPrint admin'