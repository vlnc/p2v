#!/bin/sh

# Lancement des différents scripts
# Version 3

# Controle droit utilisateur

if [ ! "$UID" -eq 0 ]; then
    echo -e "\nVous devez etre 'root' pour lancer ce script !"
    echo -en "Votre UID devrait etre '0', il est actuellement $UID\n\n"
    exit 1
fi

############
# Fonction #
############

# Fonction connection perdue ssh

function sshError {
if [ $? -eq 0 ]; then
	echo -e "Execution du script reussi via SSH"

	elif [ $? -eq 255 ]; then
		echo "Probleme de connexion"
		exit 1
else
	echo "Probleme inconnu"
	exit 1
fi
}

function scpError {
if [ $? -eq 0 ]; then
	echo -e "\n\033[32mTransfert de reussie\033[0m"	
	
	elif [ $? -eq 1 ]; then
		echo -e "\033[31mProbleme de connexion\033[0m"
		exit 1
		
else
	echo "Erreur inconnue"
	exit 1
fi	
}	

# Fonction verification ip

function checkIP {

until ipcalc -c $ip 2> /dev/null; 
    do
        echo -e "->  \033[31mAdresse IP incorrecte\033[0m"
        echo -en "\nEntrer l'adresse IP de la machine physique : "
        read ip
    done

# lance un ping de 4 paquets, attrapes les 4 lignes et les comptes
up=`ping -c 4 $ip 2> /dev/null | grep "64 bytes from $ip" | wc -l`

# tant que la valeur de $up (nombre de ping) est egal a 0 alors lhotes est hors ligne + exit sinon ..
while [ $up -eq 0 ]; do
	echo -e "\n  --> $ip is \033[31mDOWN\033[0m <--\n"
	echo -n "Entrer une adresse IP : "
	read ip
	up=`ping -c 4 $ip 2> /dev/null | grep "64 bytes from $ip" | wc -l`
done
echo -e "\n  --> $ip is \033[32mUP\033[0m <--\n"

}

# Fonction test ip



clear
echo "$(date +%d)/$(date +%m)/$(date +%Y) - $(date +%H):$(date +%I) || Vous etes actuellement sur $(hostname)"
echo -e "\n### script_start.sh ###\n"

while [ "$ip" == "" ]; do
	echo -n "Entrer l'adresse IP de la machine physique : "
	read ip
done

checkIP



while [ "$cheminDistant" == "" ]; do
	echo -n "Entrer un chemin distant : "
	read cheminDistant
done

time scp -c arcfour128 script_conv.sh root@$ip:$cheminDistant > /dev/null
scpError

echo -e "\nLancement en cours de script_conv.sh ...\n"
sleep 1

ssh root@$ip "sh $cheminDistant/script_conv.sh && exit"
sshError

echo -e "\n### Lancement de script_modifile.sh a distance ###\n"

sh script_modifile.sh

if [ $? -eq 0 ]; then
    echo "Script modifile termine correctement"
    exit 0
else
    "probleme"
    exit 1
fi
