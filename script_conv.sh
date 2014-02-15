#!/bin/sh
TERM=linux
export TERM

# Version 7
# Script Transfert image disque

# Controle droit utilisateur

if [ ! "$UID" -eq 0 ]; then
    echo -e "\nVous devez etre 'root' pour lancer ce script !"
    echo -en "Votre UID devrait etre '0', il est actuellement $UID\n\n"
    exit 1
fi


################
# Introduction #
################

# Ce script permet le transfer d'un peripherique vers un hote distant (via ssh) ou alors sur un disque de stockage externe.
# Minimum requis : ssh

########
# Draw #
########

#time dd if=$device bs=1024 | scp -c arcfour "dd of=$cheminDistant/$image" root@$ip:$cheminDistant
#echo "Envoie de l'image via ssh"
#time scp $cheminLocal/$image root@$ip:$cheminDistant
#time dd if=$device bs=1024 | ssh -c arcfour $ip "dd of=$cheminDistant/$image";;
#dd if=$dev | pv -s $var1 -petr | of=$cheminStockage/$outFile bs=1024
#echo -e "\nEnvoie du resultat du hash sha1 de $image sur $ip:$cheminDistant\n"
#time scp -c arcfour128 $cheminLocal/$image.sum root@$ip:$cheminDistant
#rsync -v --progress -e ssh  $cheminLocal/$image.sum root@$ip:$cheminDistant

#############
# Variables #
#############

mtab="/etc/mtab"

#DIALOG=${DIALOG=dialog}

#############
# Fonctions #
#############

# Menu affichage au lancement du programme

function menu {

while [[ "$choix" != "1" && "$choix" != "2" && "$choix" != "3" && "$choix" != "4" && "$choix" != "5" && "$choix" != "6" && "$choix" != "7" && "$choix" != "10" ]];
do
	clear
	echo "$(date +%d)/$(date +%m)/$(date +%Y) - $(date +%H):$(date +%I) || Vous etes actuellement sur $(hostname)"
	echo -e "\n    ########################################\n    ### Script de transfert image disque ###\n    ########################################\n"
	echo -e "Choisir par l'une des options suivantes\n"
	echo -e "1. Convertion vers montage NFS"
	echo -e "2. Convertion sur disque local et envoie via SSH"
	echo -e "3. Convertion sur disque amovible et envoie via SSH"
	echo -e "4. Convertion sur disque local seul"
	echo -e "5. Convertion sur disque amovible seul"
	echo -e "6. Aide"
	echo -e "7. Quit\n"
	echo -en "Entrer un numero : "
	read choix
done
}


# Verification du format de l adresse IP et de la connectivité

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

# Fonction verification cheminNFS

function testCheminNFS {
	
	while [ "$cheminNFS" == "" ] || [ ! -d $cheminNFS ];
	do
		echo -en "Entrer un chemin NFS pour la convertion : "
		read cheminNFS
	done

	mount | grep -o $cheminNFS > /dev/null
	
	if [ $? -eq 0 ]; then
		echo -e "\nLe chemin est deja monte\n"
	else
		until mount -t nfs $ip:$cheminNFS $cheminNFS 2> /dev/null; do
            echo -n "."
        done
	
		if [ $? -eq 0 ]; then
			echo -e "\n -> Chemin $cheminNFS monte sur $ip\n"
		else
			echo -e "\nProbleme lors du montage"
            echo -e "\nError code $?"
			exit 1
		fi
	fi
	sleep 1
}

# Fonction verification cheminLocal

function testCheminLocal {
	while [ "$cheminLocal" == "" ];
	do
		echo -en "Entrer un chemin local pour la convertion : "
		read cheminLocal
	done	

	if [ ! -d $cheminLocal ]; then
		echo -e "\nLe repertoire $cheminLocal n'existe pas.\nCreation du repertoire $cheminLocal"
		mkdir $cheminLocal
		if [ -d $cheminLocal ];then
			echo -e "\n$cheminLocal cree avec succes\n"
		else
			echo -e "\nErreur lors de la creation de $cheminLocal\n"
            echo -p "Appuyer sur une touche pour quitter"
			exit 1
		fi
	else
		echo -e "\nLe repertoire $cheminLocal existe deja\n\nUtilisation de $cheminLocal comme repertoire pour la convertion\n"
	fi
}

# Fonction testCheminStockage

function testCheminStockage {
	while [ "$cheminStockage" == "" ];
	do
		echo -n "Entrer un chemin vers stockage amovible : "
		read cheminStockage
	done

	var1=`mount | grep 'on '$cheminStockage' type' > /dev/null`

	if [ $? -eq 0 ]; then
		echo -e "\nCreation de l'image avec qemu\n"
		echo "Progression de la convertion : "
		time qemu-img convert -c -p -f raw $device -O qcow2 $cheminStockage/$image.img
	else
		echo "Le chemin $cheminStockage est introuvable"
		read -p "Appuyer sur une entree pour quitter"
		exit 1
	fi
}

# Fonction testDevice

function testDevice {

	#fdisk -l | grep "/dev/" | head -n 1 | awk {'print $2'} | sed 's/://g'; fdisk -l | grep "/dev/" |  sed 's/Disque//g' | awk {'print $1'} | sed 's/://g' | tail -n +2; echo ""
	echo -e "\nListe peripherique : \n"; fdisk -l | grep "Disk /dev/" | awk {'print $2'} | sed 's/://'; echo -e "\nListe partition : ";fdisk -l | grep "/dev/" | awk {'print $1'} | sed 's/Disk//'; echo ""
	
	listDevice=`fdisk -l | grep "/dev/" | head -n 1 | awk {'print $2'} | sed 's/://g' >> tmp.file; fdisk -l | grep "/dev/" |  sed 's/Disque//g' | awk {'print $1'} | sed 's/://g' | tail -n +2 >> tmp.file`

	while [ "$device" == "" ]; do
		echo -en "Entrer le disque a convertir : "
		read device
	done

	grep -o $device tmp.file > /dev/null

	while [ ! $? -eq 0 ] || [ "$device" == "" ] ; do
		echo -e "Le peripherique $device n'existe pas"
        echo -en "Entrer un peripherique correct : "
        read device

        while [ "$device" == "" ]; do
		    echo -en "\nEntrer le disque a convertir : "
		    read device
	    done
            
        grep -o $device tmp.file > /dev/null
    done

	rm -f tmp.file
}

# Fonction calcul sha1sum image nfs

function sumImageNFS {

echo -e "\nGeneration de la somme du fichier $image.img ..."

time sha1sum $cheminNFS/$image.img > $cheminNFS/$image.img.sum

    if [ -f $cheminNFS/$image.img.sum ]; then
        echo -en "\nSHA1SUM : "; cat $cheminNFS/$image.img.sum | awk {'print $1'}; echo ""
    else
        echo "Le fichier $cheminNFS/$image.img.sum n'existe pas "
    fi	
}

# Fonction sum de l image
function sumImageLocal {

echo -e "\nGeneration de la somme du fichier $image ..."

time sha1sum $cheminLocal/$image.img > $cheminLocal/$image.img.sum

    if [ -f $cheminLocal/$image.img.sum ]; then
        echo -e "\nLe fichier $cheminLocal/$image.sum existe"
        echo -en "\nSHA1SUM : "; cat $cheminLocal/$image.img.sum | awk {'print $1'}
    else
        echo -e "\nLe fichier $cheminLocal/$image.sum n'existe pas "
    fi
#echo -e "\nEnvoie du resultat du hash sha1 de $image.img sur $ip:$cheminDistant\n"
#time scp -c arcfour128 $cheminLocal/$image.sum root@$ip:$cheminDistant

}

# Fonction calcul sum image

function sumImageDistant {
echo -e "\nGeneration de la somme du fichier $image ..."

time sha1sum $cheminStockage/$image.img > $cheminStockage/$image.img.sum

    if [ -f $cheminStockage/$image.img.sum ]; then
        echo "Le fichier $cheminStockage/$image.sum existe"
        echo -en "\nSHA1SUM : "; cat $cheminStockage/$image.img.sum | awk {'print $1'}
    else
        echo "Le fichier $cheminStockage/$image.sum n'existe pas "
    fi
echo "Envoie du resultat du hash sha1 de $image.img sur $ip"
time scp -c arcfour128 $cheminStockage/$image.sum root@$ip:$cheminDistant
}

# fonction code erreur scp

function scpError {
if [ $? -eq 0 ]; then
	echo -e "\nTransfert de reussie"
	
	elif [ $? -eq 1 ]; then
		echo "Problème de connexion"
		exit 1
else
	echo "Erreur inconnue"
	exit 1
fi	
}

function removeImage {
while [ "$test" == "" ];
do
	echo -en "\nVoulez-vous supprimez l'image local ? (Y/N) : "
	read test
done

if [ $test == "Y" ] || [ $test == "y" ]; then
	echo -e "\nSuppression de l'image $cheminLocal/$image.img ..."
	rm -f $cheminLocal/$image.img

	if [ ! -f $cheminLocal/$image.img ]; then
			echo -e "\nFichier $image.img supprime avec succes\n"
			read -p "Appuyer sur une touche pour terminer"
			clear
	else
			echo -e "\nErreur lors de la suppression du fichier $cheminLocal/$image.img"
			exit 1
	fi

elif [ $test == "N" ] || [ $test == "n" ]; then
	echo -e "\nL'image se trouve dans $cheminLocal/$image.img"
	read -p "Appuyer sur une touche pour terminer"
	
else
	echo -e "\nChoix incorrect"
	exit 1
fi
}

function umountNFS {

cd /
until umount $cheminNFS; do 
    echo -e "\nTentative de demontage du partage NFS"
    sleep 1
done

if [ $? -eq 0 ]; then
    echo -e "Partage demonte \033[32mcorrectement\033[0m\n"
else
    echo -e "\n \033[31mProbleme\033[0m lors du demontage du partage"
fi
}

##################
# Debut Programe #
##################

menu

case $choix in

	1) 
		
        echo -e "\n ### Convertion vers chemin NFS ### \n"
            
	    while test "$ip" == ""; 
	    do
		    echo -n "Entrer l'adresse IP de l'hyperviseur : "
		    read ip
	    done


	    #Exe function checkIP
            
	    checkIP	
           
	    # Exe fonction testCheminNFS
		
	    testCheminNFS

	    # Exe fonction testDevice

	    testDevice

        while [ "$image" == "" ];
		do
			echo -n "Entrer le nom de l'image de sortie : "
			read image
		done

        echo -e "\nCreation de l'image avec qemu\n"
	
	    echo "Progression de la convertion : "
	    time qemu-img convert -c -p -f raw $device -O qcow2 $cheminNFS/$image.img
		
	
	    if [ -f $cheminNFS/$image.img ]; then
		    echo -e "\nConvertion terminee"
	    else
		    echo -e "\nErreur lors de la convertion - Aucun fichier trouve"
		    exit 1
	    fi	
		
		sumImageNFS

        umountNFS

		exit 0
		;;
	
    2)
    
        echo -e "\n ### Convertion sur disque local et envoie par SSH ### \n"
            
	    while test "$ip" == ""; 
	    do
		    echo -n "Entrer l'adresse IP de l'hyperviseur : "
		    read ip
	    done


	    #Exe function checkIP
            
	    checkIP	
           
	    # Exe fonction testCheminLocal

	    testCheminLocal

	    # Exe fonction testDevice

	    testDevice

        while [ "$image" == "" ];
		do
			echo -n "Entrer le nom de l'image de sortie : "
			read image
		done

        echo -e "\nCreation de l'image avec qemu\n"
	
	    echo "Progression de la convertion : "
	    time qemu-img convert -c -p -f raw $device -O qcow2 $cheminLocal/$image.img

	    if [ -f $cheminLocal/$image.img ];then
		    echo -e "\nConvertion terminee"
	    else
		    echo -e "\nErreur lors de la convertion - Aucun fichier trouve"
		    exit 1
	    fi
		
		while [ "$cheminDistant" == "" ];
		do 
			echo -en "\nEntrer un chemin distant pour l'envoie de l'image via SSH : "
			read cheminDistant
		done
		
		echo -e "\nProcedure d'envoie de $image.img via SSH sur $ip:$cheminDistant\n"

        time scp -c arcfour128 $cheminLocal/$image.img root@$ip:$cheminDistant
		scpError
		
	    #time rsync -v --progress -e ssh $cheminLocal/$image root@$ip:$cheminDistant		

		sumImageDistant
	
        removeImage
		
		exit 0;;
    3)
	
        echo -e "\n ### Convertion sur disque amovible et envoie par SSH ### \n"


	    while [ "$ip" == "" ]; 
	    do
		    echo -n "Entrer l'adresse IP de l'hyperviseur : "
		    read ip
	    done

	    # Exe function checkIP
            
	    checkIP	

	    # Exe fonction testDevice

	    testDevice

		while [ "$image" == "" ]; 
		do
        	echo -n "Entrer le nom de l'image de sortie : "
        	read image
		done

		echo -e "\nCreation de l'image avec qemu\n"
	
	    echo "Progression de la convertion : "
	    time qemu-img convert -c -p -f raw $device -O qcow2 $cheminLocal/$image.img
		
		testCheminStockage
		
		while [ "$cheminDistant" == ""];
		do
			echo -en "\nEntrer un chemin distant pour l'envoie de l'image via SSH : "
			read cheminDistant
		done
		
		time scp -c arcfour128 $cheminStockage/$image.img root@$ip:$cheminDistant
        
        sumImageLocal

        ;;
		
    4)
	
        echo -e "\n ### Convertion sur disque local seul  ### \n"
	
		# Exe fonction testCheminLocal

	    testCheminLocal

	    # Exe fonction testDevice

	    testDevice

        while [ "$image" == "" ];
		do
			echo -n "Entrer le nom de l'image de sortie : "
			read image
		done

        echo -e "\nCreation de l'image avec qemu\n"
	
	    echo "Progression de la convertion : "
	    time qemu-img convert -c -p -f raw $device -O qcow2 $cheminLocal/$image.img

	    if [ -f $cheminLocal/$image.img ];then
		    echo -e "\nConvertion terminee"
	    else
		    echo -e "\nErreur lors de la convertion - Aucun fichier trouve"
		    exit 1
	    fi
	
		sumImageLocal
		exit 0
		;;
	5)

		echo -e "\n ### Convertion sur disque amovible seul  ### \n"

		echo -en "\nEntrer le disque a transferer : "
		read device

		checkDevice=`fdisk -l | grep -o $device`

		if [ $? -eq 0 ]; then
			echo -e "\n$device \033[32mtrouve\033[0m.\n"
		else
			echo -e "\n$device \033[31mnon trouve\033[0m.\n"
			exit 1
		fi	 
		
		echo -n "Entrer le nom de l'image de sortie : "
		read image

		echo -n "Entrer un chemin vers stockage amovible : "
		read cheminStockage

		grep -o $cheminStockage /etc/mtab 2> /dev/null
		
		# Contient l'espace total du peripherique
		var1=`fdisk -l | grep "Disk $device" | awk '{print $3}' | cut -d. -f 1`

		if [ $? -eq 0 ]; then
			echo -e "\nCreation de l'image avec qemu\n"
			echo "Progression de la convertion : "
			time qemu-img convert -c -p -f raw $device -O qcow2 $cheminStockage/$image.img
			echo -n "SHA1SUM : "		
			sumImageDistant
		else
				echo -e "\nLe chemin n'est pas monte\n"
		fi
		exit 0
		;;

    6)
	
		echo -e "\n\n ##########\n ## AIDE ##\n ##########\n\n"
		echo -e "Ce script permet de transferer un peripherique type /dev/sda (linux uniquement - surtout fedora) vers un hote distant via ssh ou sur un disque de stockage externe\n\nNe supporte pas LVM !\n\n Appuyer sur ENTER pour continuer ..."
		read
		./script_conv.sh
		;;

    7)
		exit 0;;
		
	10)
		echo "Happy easter egg";;
esac
