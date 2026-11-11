# SelectiveLoot

*[English version](README.md)*

Addon pour **World of Warcraft: Forever** : tu fouilles comme d'habitude, l'addon ramasse tout **sauf** les objets que tu as choisi d'ignorer.

## Fonctionnalités

- **Filtre de butin** : tout est ramassé (or, objets, monnaies), sauf les objets de ta liste d'ignorés. Les objets de quête sont toujours ramassés.
- **Une liste par personnage** : chaque personnage a sa propre liste d'objets ignorés. Les réglages, eux, sont communs au compte.
- **Maj+clic** sur un cadavre ramasse tout, filtre compris.
- **Raccourci clavier** : survole un objet (sac, butin, banque…) et appuie sur ta touche pour l'ignorer ou le ramasser à nouveau.
- **Infobulles** :
  - objet ignoré : ligne rouge « Ignoré au ramassage » (rien n'est ajouté pour les autres objets) ;
  - cadavre déjà fouillé : ligne verte « Fouillé », avec le nombre d'objets ignorés laissés ;
  - cadavre pas encore fouillé : ligne jaune « Pas encore fouillé ».
- **Affichage du butin** : la fenêtre de butin est remplacée par une liste à l'écran de ce que tu ramasses, dans le style des objets de la fenêtre de butin (icône dans son emplacement, nom sur le cartouche parchemin, couleur de qualité). Elle apparaît et disparaît en fondu, et montre aussi les objets ignorés laissés (icône grisée, croix rouge). Taille, durée, nombre de lignes et opacité du cartouche réglables. Pour la déplacer : glisse l'aperçu quand les options sont ouvertes, ou maintiens **Ctrl** et fais-la glisser en jeu.
- **Options dans le menu du jeu** (Options > AddOns > SelectiveLoot, ou `/sl`) :
  - état du filtre, du butin automatique du jeu et du raccourci, avec un bouton pour corriger ;
  - choix du raccourci directement depuis le panneau, avec avertissement si la touche est déjà utilisée ;
  - liste des objets ignorés : ajout par ID, lien ou glisser-déposer, bouton « Retirer » sur chaque ligne ;
  - langue : automatique (langue du jeu), anglais ou français.

Code couleur partout : **vert** = c'est bon, **jaune** = à faire, **rouge** = problème ou objet ignoré, **gris** = détail.

## Installation

1. Télécharge l'addon sur CurseForge, ou ce dépôt (bouton **Code > Download ZIP**).
2. Copie le dossier `SelectiveLoot` dans `World of Warcraft\_forever_\Interface\AddOns\`.
3. En jeu, tape `/sl` : si le butin automatique du jeu est activé, clique sur **Corriger** (le filtre en a besoin), puis choisis ton raccourci.

Ne copie pas le dossier `tests` dans le jeu.

## Commandes

| Commande | Effet |
|---|---|
| `/sl` | Ouvre les options |
| `/sl add <lien ou ID>` | Ignore un objet |
| `/sl del <lien ou ID>` | Ne l'ignore plus |
| `/sl on` / `/sl off` | Active ou désactive le filtre |
| `/sl move` | Déverrouille / verrouille l'affichage du butin |
| `/sl debug` | Affiche une trace des fouilles dans le chat, pour signaler un bug |

## Limites connues

- Le scintillement des cadavres est géré par le jeu, pas par l'addon. Dans WoW Forever, il s'arrête dès qu'un corps a été fouillé, même s'il reste des objets ignorés dessus : l'infobulle « Fouillé » indique combien il en reste.
- La fenêtre de butin peut s'afficher une fraction de seconde avant de se refermer quand il ne reste que des objets ignorés.
- Si le jeu masque l'identité des cadavres aux addons, les lignes « Fouillé » / « Pas encore fouillé » n'apparaissent pas. Le filtre continue de fonctionner.

## Traductions

L'anglais et le français sont inclus. Les textes sont dans [`SelectiveLoot/Locales.lua`](SelectiveLoot/Locales.lua) : pour ajouter une langue, copie la table `enUS`, traduis-la et ajoute la langue à `ns.LANGUAGES`.

## Tests

`tests/!SelectiveLootSandbox` simule le butin, des cadavres, un sac, le menu Options et les raccourcis pour tester l'addon dans [wow-addons-sandbox](https://github.com/srrmke/wow-addons-sandbox) sans lancer le jeu. Les captures sont dans `tests/captures`.

## Licence

[MIT](LICENSE) : tu peux utiliser, modifier et redistribuer l'addon librement, à condition de garder la mention de copyright.
