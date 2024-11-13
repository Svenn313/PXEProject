#!/bin/bash

## Suppression de certains fichier temporaire ##
sudo rm /home/sven/PXEProject/Ansible/.pxesshkey*

## Demande des informations sur la personne a ajouté a la BDD ##
read  -p "Nom et Prenom de la nouvelle personne: " newSurnameAndName
read  -p "Poste de la personne: " newPosition
read  -p "Type de contrat de la personne : " newContractType
read  -p "Date de début de la personne (format YYYYMMDD): " newStartDate
read  -p "Date de fin de la personne (format YYYYMMDD) (ne rien mettre si vous ne savez pas): " newEndDate


## Création et setup de la paire de clef SSH ##
echo "création de la paire de clef SSH pour $newSurnameAndName"
sudo ssh-keygen -f /home/sven/PXEProject/Ansible/.pxesshkey -t ed25519 -q -N ""
sudo cat /home/sven/PXEProject/Ansible/.pxesshkey.pub > "$newSshpubkey"
sudo cat /home/sven/PXEProject/Ansible/.pxesshkey.pub > authorized_keys

## Modification du playbook de création des utilisateurs et création du login ##
echo $newSurnameAndName > username.txt
awk '{print tolower($0)}' username.txt | tr " " "." > usernameformat.txt
ansibleUsername=$(< usernameformat.txt)
rm username.txt

## Vérification du nombres de machines disponibles sur la plage DHCP attribué pour le PXE ##
## Si il y a plusieurs machines : on demande a l'utilisateur sur laquel il souhaite installer le compte ##
fping -gaq 192.168.1.40 192.168.1.49 > ping.txt
pingtest="ping.txt"
lineCount=$(wc -l < "$pingtest")

if [ "$lineCount" -gt 1 ]; then
    echo "Il y a plus d'un ordinateur disponible pour la configuration automatique\n"
    echo -e "-----"
    cat -n ping.txt
    echo -e "-----\n"
    read -p "Quel ordinateur doit etre configuré ? (mettre le numero de la ligne correspondant a l'IP) : " laptopnumber
    while true; do
        if [[ "$laptopnumber" =~ ^[0-9]+$ ]] && [ "$laptopnumber" -ge 1 ] && [ "$laptopnumber" -le "$lineCount" ]; then
            laptopIP=$(sed -n "${laptopnumber}p" ping.txt)
            ansible-playbook -i $laptopIP, createuser.yaml --user=user1 --ask-pass -e "username="$ansibleUsername""
            break
        else
            echo "Numéro de ligne invalide."
                echo -e "-----\n"
                cat -n ping.txt
                echo -e "-----\n"
                read -p "Veuillez entrer un numéro entre 1 et $lineCount : " laptopnumber
        fi
    done
else
    ansible-playbook -i inventory createuser.yaml -e "username="$ansibleUsername""
fi

## Modification de la BDD ##
echo "Ajout de $newSurnameAndName à la base de données"
psql -h localhost -p 5432 -U sven postgres << EOF
insert into main(name,position,sshkey,contracttype,startdate,enddate)
values ('$newSurnameAndName','$newPosition','$newSshpubkey','$newContractType' , '$newStartDate', '$newStartDate' );
EOF

sudo rm /home/sven/PXEProject/Ansible/.pxesshkey*
