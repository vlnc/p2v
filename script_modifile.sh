#!/bin/sh

# Version 5

# Controle droit utilisateur

if [ ! "$UID" -eq 0 ]; then
    echo -e "\nVous devez etre 'root' pour lancer ce script !"
    echo -en "Votre UID devrait etre '0', il est actuellement $UID\n\n"
    exit 1
fi

#############
# Variables #
#############

#GenMAC=`echo 'import virtinst.util ; print virtinst.util.randomMAC()' | python`
GenMAC=`printf '54:52:00:%02X:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))`
GenUUID=`echo 'import virtinst.util ; print virtinst.util.uuidToString(virtinst.util.randomUUID())' | python`

########
# DRAW #
########

#var1=`fdisk -l $imageRaw | grep Linux | awk '{print $3}' | head -n 1`
#calcVar1=`echo $(($var1*512))`
#mount -o loop,rw,offset=$calcVar1 $imageRaw $workDir 2> /dev/null
#mount | grep $imageRaw > /dev/null

############
# Fonction #
############

function sumImage {
# Le chemin d'origine peut etre different de celui de destination, il faut donc remplacer par le bon chemin dans le fichier .sum
hash=`awk {'print $2'} $image.sum`
sed -i "s%$hash%$image%" $image.sum

echo -e "\nVerification de l'integrite de $image ...\n"

# On check le sum de l'image
time sha1sum -c $image.sum

# Si le résultat de la commande sum est = a 0 alors le fichier est sain sinon corrompu
if [ $? -eq 0 ]; then
    echo -e "\nLe fichier n'est pas corrompu - \033[32mCHECKSUM OK\033[0m"
else
    echo -en "\nLe hash suivant \033[31mne correspond pas\033[0m : "
    cat $image.sum | awk {'print $1'}
    echo -e "Veuillez re-transferer l'image disque"
    read -p "Appuyer sur une touche pour sortir"
    exit 1
fi
}

function checkMount {

# Si le resultat de la commande = 0 alors l'image est monté, sinon pb de montage et sortie
if [ $? -eq 0 ]; then
	echo -e "\n\033[32m > La partition est monte dans $workDir\033[0m\n\nMontage : $(mount | grep $workDir)"
else 
	echo -e "\n\033[31m > Probleme de montage avec l'image $image\033[0m"
	exit 1
fi

}

echo -e "\n######################################\n### Modification de l'image disque ###\n######################################\n"

while [ "$image" == "" ]; do 
    echo -n "Entrer le chemin complet vers l'image disque : "
    read image

    while [ ! -f $image ]; do
        echo "fichier introuvable: $image"
        echo -n "Entrer le chemin complet vers l'image disque : "
        read image
    done       
done

sumImage

#Quelques input user pour le chemin pour monter l'image et le fichier image de la machine convertie

while [ "$workDir" == "" ]; do
    echo -en "\nEntrer un chemin pour monter l'image : "
    read workDir
done

#Si le dossier n'existe pas, creation du dossier, s'il n'existe toujours pas sortie sinon on continu
if [ ! -d $workDir ];then
	echo -e "\nLe repertoire n'existe pas"
	echo -e "\nCreation du repertoire"
	mkdir $workDir

	if [ ! -d $workDir ];then
		echo -e "\n\033[31m > Probleme lors de la creation du repertoire $workDir\033[0m"
		exit 1
	fi
fi

echo -e "\nTentavice de montage de l'image $image dans le repertoire $workDir ...\n"

rmmod nbd 2> /dev/null
modprobe nbd max_part=15

echo -e "Ajout module nbd au kernel en cours ...\n"; echo -n "Chargement "; for ((var=0; var < 3; var++)); do echo -ne "."; sleep 1; done; echo ""

while [ ! -e "/dev/nbd0" ]; do 
	echo "/dev/nbd0 en cours d'utilisation ..."
	sleep 1
done

# Partie de montage de l'image avec qemu-nbd


qemu-nbd -c /dev/nbd0 $image

# Si la connection du device /dev/nbd0 fonctionne ou non 
if [ $? -eq 0 ];then
    echo -e "\nDevice \033[32m/dev/nbd0\033[0m connected to $image"
else
    echo -e "\nCan't connect \033[31m/dev/nbd0\033[0m to $image"
    exit 1
fi
sleep 1

mount /dev/nbd0p1 $workDir
#mount /dev/nbd0 $workDir

checkMount

echo -e "\n################################\n# Modification du fichier grub #\n################################\n"

echo "Modification du fichier device.map"

var1=`find $workDir -name "device.map"`

if [ $? -eq 0 ]; then
	vi $var1
else
	echo "Le fichier device.map est introuvable"
fi

umount $workDir

mount /dev/nbd0p2 $workDir

#checkMount

echo -e "\nListe des interface reseaux : \n"

# Affiche les interfaces phydiques en excluant localhost
ls $workDir/etc/sysconfig/network-scripts | grep -v "ifcfg-lo" | grep "ifcfg-*"

varifcfg=`ls $workDir/etc/sysconfig/network-scripts | grep -v "ifcfg-lo" | grep "ifcfg-*" | wc -l`

echo -en "\nEntrer le nom de l'interface : "
read ifCfg

echo "Creation du fichier ifcfg-eth0"
touch ifcfg-eth0 $workDir/etc/sysconfig/network-scripts/

network="$workDir/etc/sysconfig/network"
interfaceOrigine="$workDir/etc/sysconfig/network-scripts/$ifCfg"
interfaceDestination="$workDir/etc/sysconfig/network-scripts/ifcfg-eth0"

cat $interfaceOrigine > $interfaceDestination

echo -e "\n##############################\n# Modification du nom d'hote #\n##############################\n"

# Modification du nom d'hote

echo -n "Entrer le nom de la machine virtuelle : "
read vHostname

sed -i -e s/^HOSTNAME=.*/HOSTNAME=$vHostname/ $network 2> /dev/null

echo -e "\n################################\n# Modification de l'adresse IP #\n################################\n"

# Modification de l'adresse IP de la machine si elle est en IP fixe

if [ $(grep -o "IPADDR" $interfaceDestination) ]; then
	while [ "$ip" == "" ]; do
		echo -n "Entrer une nouvelle adresse IP : "
		read ip
	done
	sed -i -e s/^IPADDR=.*/IPADDR=\"$ip\"/ $interfaceDestination 2> /dev/null
else
	echo "Pas d'adresse a modifier"
fi

# Modification de la variable DEVICE

sed -i -e s/^DEVICE=.*/DEVICE=\"eth0\"/ $interfaceDestination 2> /dev/null

echo -e "\n#################################\n# Modification de l'adresse MAC #\n#################################\n"

echo -e "\nGeneration aleatoire d'une adresse MAC\nAdresse MAC : $GenMAC\n"

sed -i -e s/^HWADDR=.*/HWADDR=\"$GenMAC\"/ $interfaceDestination 2> /dev/null

############################################################
# Recuperation de parametre concernant la machine physique #
############################################################

#memTotal=`grep "MemTotal:" $workDir/proc/meminfo | awk {'print $2'}`
#cpuTotal=`grep "processor" $workDir/proc/cpuinfo | wc -l`

########################
# Demontage de l'image #
########################

umount $workDir

if [ $? -eq 0 ]; then
    echo "Partition demonte correcement"
    elif [ $? -eq 32 ]; then
        echo "codeError = 32"
        cd /
        umount $workDir
    
else
    echo "Erreur inconnue"
    exit 1
fi

qemu-nbd -d /dev/nbd0 > /dev/null

if [ $? -eq 0 ]; then
    echo -e "\nqemu-nbd deconnecte correctement"
else
    echo -e "\nProbleme deconnection qemu-nbd"
fi

echo -e "\n#######################\n# Ajout dans virt-mgr #\n#######################\n"

#echo -e "Memoire total de la machine physique : $(($memTotal/1024)) Mo"

while [ "$vMemory" == "" ]; do
	echo -n "Entrer la memoire pour $vHostname : "
	read vMemory
done

#echo -e "\nNombre de processeur de la machine physique : $cpuTotal\n"

while [ "$CPU" == "" ]; do
	echo -n "Entrer le nombre de CPU pour $vHostname : "
	read CPU
done

echo -e "\nListe d'OS : \n\n"
virt-install --os-variant list

while [ "$osVariant" == "" ]; do
	echo -en "\nEntrer le nom de la distribution en fonction de la liste : "
	read osVariant
done

#virt-install --connect=qemu:///system --name $vHostname --ram $vMemory -u $GenUUID --vcpus=$CPU -m $GenMAC --os-type=linux --os-variant=$osVariant --disk $image,format=qcow2,bus=virtio,cache=none --network=bridge:vnet0,model=virtio --keymap=fr --boot hd

virt-install --connect=qemu:///system --name $vHostname --ram $vMemory -u $GenUUID --vcpus=$CPU -m $GenMAC --os-type=linux --os-variant=$osVariant --disk $image,format=qcow2,bus=virtio,cache=none --network=bridge:virbr0 --keymap=fr --boot hd

echo -n "Chargement "; for ((var2=0; var2 < 3; var2++)); do echo -ne "."; sleep 1; done; echo ""

echo "Dump de la configuration de la machine virtuelle $vHostname"

if virsh dumpxml $vHostname > /home/dumpxml_$vHostname; then
    echo "Le fichier se trouve dans /home/dumpxml_$vHostname"
    exit 0
else
    echo "Une erreur est survenue lors du dump (exitCode $?)"
    exit 1
fi

virsh list --all

exit 0
