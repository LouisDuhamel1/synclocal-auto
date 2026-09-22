# synclocal-auto

## Description
Le but du projet est de faire une synchronisation automatique à partir d'un dossier source vers un dossier où l'on veut faire la sauvegarde. Il contient un fichier exécutable en `.cmd` et il contien également un script de démarrage automatique à chaque connexion.

##### Ne pas oublier de brancher le support de stockage amovible avant la connexion à toute session !!!! (démarrage automatique impossible)

### Comment marche l'exécutable?
 
Le script contient un fichier cmd (`sync-toggle.cmd`) où on peut cliquer dessus pour l'arrêter ou le démarrer. La première fois il va simplement lancer l'étape de la première configuration
dans le code du script principale. A préciser que vous pouvez savoir quand le processus est en cours grâce au fichier `sync.pid` qui sera créer grâce au script princiaple pour qu'il tourne en arrière plan sans avoir besoin d'ouvrir une fenêtre.

### Comment marche le script principale ?

Le fichier s'occupant de la synchronisation `sync.ps1` fonctionne pour la première fois en demandant le dossier source puis le dossier de destination en suite il va sauvegarder la configuration dans le fichier `sync-config.json` et vous n'avez normalement plus rien n'a touché.

### Comment marche le script automatique ?

Le script s'occupant du démarrage automatique `activate-start-auto.ps1` sert à chaque connexion de session avec le dossier source ou de destination connecté de démarrer automatiquement le script sans avoir besoin de démarrer manuellement le script.



[Lien vers la release](https://github.com/LouisDuhamel1/synclocal-auto/releases/tag/Inintial)

