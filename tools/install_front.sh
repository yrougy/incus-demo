#!/usr/bin/env bash


generate_certificates()
{
	if [ -f certificates/incusPortal.key ]
	then
		echo Certificates seems to be already here
		echo -n "Do you want to delete them and create new certificates ? [N/y] "
		read ans tmp
		if [ "$ans" != "y" ]
		then
			return
		fi	
	fi
	mkdir -p certificates
	echo -n "Generating certificates"
	openssl genpkey -algorithm ED25519 -out certificates/incusPortal.key
	echo -n .
	openssl pkey -in certificates/incusPortal.key -pubout -out certificates/incusPortal.pub
	echo -n .
	openssl req -new -key certificates/incusPortal.key -out certificates/incusPortal.csr -config req.conf -batch
	echo -n .
	openssl x509 -req -days 365 -in certificates/incusPortal.csr -signkey certificates/incusPortal.key -out certificates/incusPortal.crt > /dev/null 2>&1
	echo -n .ok
	echo
}

indent_string()
{
	# For the YAML file, we need correct indentation
	# It happens all the keys/cert needed must be at 6 char from the start of the line
	# So we add 6 spaces from the start
	# (yaml i don't love you)
	ret=""
	while IFS= read -r line
	do
		ret+="      $line"$'\n'
	done <<< "$1"
	echo "$ret"
}

create_conf()
{
	echo -n "Name or IP of the Incus Server with the port (localhost:8443): "
	read SERVER tmp
	echo -n "Name of the Incus Cluster: "
	read CLUSTER tmp
	# Get the certificate from the Incus Server
	IncusCertif=$(openssl s_client -connect "$SERVER" -showcerts </dev/null 2>/dev/null | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/')
	IncusIndentedCertif=$(indent_string "$IncusCertif")
	# Get the private key for authentication
	IncusKey=$(cat certificates/incusPortal.key)
	IncusIKey=$(indent_string "$IncusKey")
	# Get the generated certificate
	IncusCert=$(cat certificates/incusPortal.crt)
	IncusICert=$(indent_string "$IncusCert")
	awk -v cert="$IncusIndentedCertif"   \
		-v srvip="$SERVER"  \
		-v cluster="$CLUSTER" \
		-v incuscrt="$IncusICert" \
		-v incuskey="$IncusIKey" \
		'
	{
		gsub( /%WEBCERT%/, cert)
		gsub( /%SERVERIP%/, srvip)
		gsub( /%NOMCLUSTER%/, cluster)
		gsub( /%CRT%/, incuscrt)
		gsub( /%KEY%/, incuskey)
		print
	}' conf.tmplt > config.yaml
}


generate_certificates

create_conf 

echo "Configuration done..."
cp certificates/incusPortal.crt .
echo "Copy the config.yaml file on the root directory of the server"
echo "copy the incusPortal.crt file on the Incus server and add it to the trusted certificates with"
echo "-----------------------------------------------------"
echo "incus config trust add-certificate incusPortal.crt"
echo "-----------------------------------------------------"
