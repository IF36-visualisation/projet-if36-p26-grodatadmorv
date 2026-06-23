# GroDataDmorv — Analyse de l'équilibrage de Pokémon
![Logo de Grodatadmorv](img/grodatadmorv.png)

## Introduction

### Pokémon

Pokémon Rouge et Vert sont des jeux de rôle japonais (J-RPG) sortis initialement en 1996 au Japon. L'objectif du jeu est de capturer, élever et faire s'affronter des créatures, les Pokémon, dans des combats au tour par tour. Pour plus d'informations à ce sujet, se référer à [cette page Wikipédia](https://fr.wikipedia.org/wiki/Système_de_jeu_de_Pokémon) ou à [la page Poképédia dédiée](https://www.pokepedia.fr/Combat_Pokémon)  au système de combat.

### Pourquoi faire de la visu sur Pokémon ?

Premièrement, parce que nous aimons ces jeux. Cette raison se suffirait presque à elle-même si Pokémon n'était pas aussi riche dans ses systèmes de jeu et dans son volet compétitif qu'il ne l'est et qu'il ne l'est devenu. Nous n'arborderons pas ou très peu dans cette analyse les produits dérivés du jeu (cartes, animés, peluches, mangas, transport aérien ([oui oui](https://www.ana.co.jp/fr/fr/the-ana-experience/pikachujet/))…), qui constituent en réalité le cœur de la stratégie pour la licence la plus lucrative de l'Histoire. Les jeux et leurs mécaniques seuls constituent déjà un sujet extrêmement vaste que nous tâcherons toutefois de couvrir dans toute sa diversité.

## Données

Nous proposons d'étudier l'équilibrage de Pokémon sous deux angles complémentaires :

- angle RPG : ce que le jeu propose (stats, attaques, types, talents, répartition des créatures dans l'espace de jeu, etc.)
- angle compétitif : ce qu'en font les joueurs en stratégie Pokémon (usages, combinaisons, movesets, etc.)

L'idée est de croiser ces deux niveaux pour mieux comprendre si les Pokémon performants en compétitif le sont parce que leurs caractéristiques de base sont plus favorables, ou parce que le contexte du métagame amplifie certains profils.

### Sources

Nos deux sources sont les [statistiques de Smogon](https://smogon.com/stats/), développeurs du simulateur de jeu open-source [*Pokémon Showdown*](https://play.pokemonshowdown.com), et [PokeAPI](https://github.com/pokeapi/pokeapi), une API open-source qui donne des données générales sur les Pokémon.

#### 1) Statistiques Smogon (usage/métagame)

| Champ | Valeur |
|---|---|
| Nom | Statistiques Smogon (usage/métagame) |
| Fichier | `data/gen1ou-0.txt` |
| Format | `txt` (texte semi-structuré par blocs) |
| Dimensions | `5 346 lignes`, `107 blocs Pokémon` |

| Variable | Type | Description |
|---|---|---|
| `nom du Pokémon` | Catégorielle nominale | - |
| `raw count` | Quantitative discrète | - |
| `viability ceiling` | Quantitative discrète (ordinale) | Score de viabilité plafond |
| `% usage moves` | Quantitative continue | - |
| `% teammates` | Quantitative continue | - |
| `checks/counters score` | Quantitative continue | Indicateurs d'efficacité défensive/offensive |

#### 2) PokeAPI - Table Pokémon

| Champ | Valeur |
|---|---|
| Nom | PokeAPI - Table Pokémon |
| Fichier | `data/pokemon.csv` |
| Format | `csv` |
| Dimensions | `1 350 observations`, `8 variables` |

| Variable | Type | Description |
|---|---|---|
| `id` | Quantitative discrète | - |
| `identifier` | Textuelle / catégorielle nominale | - |
| `species_id` | Catégorielle | - |
| `height` | Quantitative discrète | - |
| `weight` | Quantitative discrète | - |
| `base_experience` | Quantitative discrète | - |
| `order` | Quantitative discrète | - |
| `is_default` | Binaire | `0` / `1` |

#### 3) PokeAPI - Table des stats

| Champ | Valeur |
|---|---|
| Nom | PokeAPI - Table des stats |
| Fichier | `data/pokemon_stats.csv` |
| Format | `csv` |
| Dimensions | `8 100 observations`, `4 variables` |

| Variable | Type | Description |
|---|---|---|
| `pokemon_id` | Catégorielle encodée (ID) | - |
| `stat_id` | Catégorielle encodée (ID) | - |
| `base_stat` | Quantitative discrète | - |
| `effort` | Quantitative discrète | - |

#### 4) PokeAPI - Tables des types

| Champ | Valeur |
|---|---|
| Nom | PokeAPI - Table des types Pokémon |
| Fichier | `data/pokemon_types.csv` |
| Format | `csv` |
| Dimensions | `2 115 observations`, `3 variables` |

| Variable | Type | Description |
|---|---|---|
| `pokemon_id` | Catégorielle encodée (ID) | - |
| `type_id` | Catégorielle encodée (ID) | - |
| `slot` | Ordinale discrète | `1` = type principal, `2` = type secondaire |

| Champ | Valeur |
|---|---|
| Nom | PokeAPI - Table des noms de types |
| Fichier | `data/type_names.csv` |
| Format | `csv` |
| Dimensions | `210 observations`, `3 variables` |

| Variable | Type | Description |
|---|---|---|
| `type_id` | Catégorielle encodée (ID) | - |
| `local_language_id` | Catégorielle encodée (ID) | - |
| `name` | Textuelle | - |


#### À propos des données

Sous-groupes naturels dans les données :

- par génération
- par format compétitif (OU, UU, formats spécifiques à une généraiton, etc.)
- par type


Nous nous réservons la possibilité d'enrichir les données présentées ici avec l'entièreté de la base de données de Smogon (les données sont dans le même format, mais pour différents formats de jeux et à différentes dates) ainsi qu'avec les autres fichiers de la base de données de PokeAPI (dans le but de plus simplement croiser les données)

## Plan d'analyse

Nous tâcherons de déterminer comment sont caractérisés les Pokémon les plus performants au niveau compétitif, et comment l'équilibrage des jeux est-il géré entre les mécaniques de RPG et le volet stratégique.

### Questions d'analyse visées

#### Stratégie

1. Quels Pokémon sont les plus utilisés, et lesquels sont sous-représentés dans le métagame étudié ? (`smogon`)
2. Les Pokémon les plus joués ont-ils des profils de stats particuliers (vitesse, attaque, bulk) ? (`smogon`, `pokemon_stats.csv`)
3. Quel est la génération la plus représentée parmis les pokemon les plus joués de chaque génération ? (`smogon`)
4. En regardant sur plusieurs Metagame smogon au fil des ans, peut-on voir une évolution dans l'utilisation des Pokemon des premières générations ? Si oui dans quels sens et quelles peuvent être les raisons ? (`smogon`)
5. Observe-t-on des combinaisons récurrentes (teammates) qui signalent des synergies fortes ? (`smogon`)
6. Quel type d'attaque sont les plus utilisés dans les différentes générations ? Est-ce corrélé avec le type le plus présent de chaque tier ? (`smogon`)
7. Quels facteurs (attaques, talents, stats) expliquent le bannissement d'un Pokémon de l'OverUsed ? (`smogon`, `moves.csv`, `abilities.csv`, `pokemon_stats.csv`)
    
#### Équilibrage & Game Design

8. La distribution des statistiques est-elle équlibrée au sein d'une même génération ? Certains Pokémon ont-ils un profil plus spécialisé (ex: haute attaque faible attaque spéciale), certains sont-ils plus homogènes ? (`pokemon_stats.csv`)
9. Certains types sont-ils sur ou sous-représentés parmi les Pokémon dominants ? Quels types semblent être les meilleurs ? les pires ? (`smogon`, `pokemon.csv`, `pokemon_types.csv`)
10. Quels sont les doubles types les plus représentés dans le jeu ? Y-a-t-il un type qui est moins/plus associés que les autres types ? (`pokemon_types.csv`)
11. Certains types ont-ils un avantage offensif/défensif intrinsèque dans le tableau des faiblesses/résistances (couverture, immunités) ? Est-ce que ça se reflète dans les choix de design des Pokémon de ces types ? (`type_efficacy.csv`, `pokemon_types.csv`)
12. Les nouvelles générations introduisent-elles beaucoup plus d'attaque et de talent uniques que les anciennes ? (`moves.csv`, `abilities.csv`)
13. Quels sont les Pokémon les plus communs, ceux que l'on va rencontrer le plus fréquemment dans chaque région ? Les plus rares ? (`encounters.csv`, `locations.csv`)
14. Comment sont répartis les « bons » Pokémon dans l'espace de jeu ? Un joueur accède-t-il naturellement à ces Pokémon ? (`smogon`, `encounters.csv`, `locations.csv`)
15. Y a-t-il une corrélation entre le BST (Base Stat Total) d'un Pokémon et son stade d'évolution / son moment d'obtention dans le jeu ? (`pokemon_stats.csv`, `pokemon_evolution.csv`, `encounters.csv`)
16. Comment évolue la difficulté des dresseurs (stats des Pokémon adverses) ou des Pokémon sauvages au fil du scénario ? La courbe de progression est-elle équilibrée ? (`pokemon_stats.csv`, `encounters.csv`)
17. Le "taux de capture" (Capture Rate) est-il strictement anti-corrélé aux statistiques du Pokémon ? Certains Pokémon faibles sont-ils artificiellement insupportables à attraper ? A-t-il baissé en moyenne dans le temps ? (`pokemon_species.csv`, `pokemon_stats.csv`)

#### Conception du bestiaire

18. Existe-t-il des stéréotypes de conception entre l'apparence des Pokémon (couleur principale, forme physique) et leur type ou leurs statistiques ? (e.g.: les Pokémon rouges sont-ils généralement de type Feu et ont-ils une attaque plus élevée ?) (`pokemon_colors.csv`, `pokemon_shapes.csv`, `pokemon_species.csv`, `pokemon_stats.csv`)
19. L'habitat naturel d'un Pokémon (grotte, forêt, zone urbaine…) correspond-il à son type (e.g.: Plante = forêt), ou y a-t-il une certaine diversité par environnement ? (`pokemon_habitats.csv`, `pokemon_types.csv`, `pokemon_species.csv`)
20. Comment ont évolué les caractéristiques biologiques telles que la taille, le poids ou le dimorphisme sexuel au fil des générations ? (`pokemon.csv`, `pokemon_species.csv`)
 
### Comparaisons et analyses prévues

- usage compétitif vs Puissance brute (Stats & Types) : déterminer si le metagame est dicté par les mathématiques (BST élevés et efficacités des types supérieurs) ou si d'autres paramètres entrent en jeu
- narratif et progression vs stratégie : confronter l'accessibilité d'un Pokémon (taux de rencontre, localisation) avec sa viabilité à haut niveau, afin de déduire si le jeu est pensé pour "récompenser" le joueur en fin d'aventure
- profils offensifs vs défensifs : mettre en lumière l'architecture classique des combats en comparant les tendances des "sweepers" (haute vitesse / attaque) face aux "tanks" (haut bulk)
- design visuel vs rôle en jeu : découvrir les éventuelles règles de conception explorant les corrélations entre couleurs, formes, habitats et rôles statistiques.

Ce que l'on souhaite obtenir :

- des visualisations lisibles de la structure du jeu et du metagame
- des hypothèses sur les mécanismes d'équilibrage
- des pistes pour expliquer les écarts entre puissance théorique (RPG) et performance réelle (compétitif)

### Limites anticipées

- possible hétérogénéité entre générations : les statistiques, les attaques mécaniques et parfois même le type des Pokémon évoluant d'une génération à l'autre, croiser plusieurs générations sans les filtrer strictement peut engendrer des incohérences.
- biais de popularité (usage joueur) qui ne mesure pas toujours la puissance intrinsèque
- la complexité d'agrégation d'une créature : évaluer mathématiquement un Pokémon pour la visualisation implique de faire l'impasse sur des détails contextuels : la viabilité se base fortement sur les spécificités uniques des attaques et des talents (Ability), ce qui est difficilement réductible à des statistiques globales sans perte sémantique
- la nature complexe de l'angle RPG : des paramètres majeurs de la difficulté ("IA" de jeu, utilisation d'objets curatifs par les PNJ, composition des arènes) ne sont pas quantifiables via nos données actuelles, et limitent l'exactitude des conclusions sur la difficulté 
