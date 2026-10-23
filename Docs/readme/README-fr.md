<div align="center">

<img src="../../Design/Logo/readme-logo.svg" width="96" height="96" alt="观我 · ScaleMe">

# 观我

### ScaleMe

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black?logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift)](https://www.swift.org/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue)](https://developer.apple.com/xcode/swiftui/)
[![Bluetooth LE](https://img.shields.io/badge/Bluetooth-LE-0A3D91?logo=bluetooth)](https://www.bluetooth.com/)
[![Stockage sur l’appareil](https://img.shields.io/badge/Data-On%20Device-2E8B57)](#data-storage-and-privacy)

Une application iOS native pour suivre le poids et la composition corporelle

**Observez les changements de votre corps et suivez votre parcours de santé.**

[简体中文](../../README.md) | [繁體中文](README-zh-Hant.md) | [English](README-en.md) | [日本語](README-ja.md) | [**Français**](README-fr.md) | [Deutsch](README-de.md) | [Español](README-es.md) | [Português](README-pt.md) | [Русский](README-ru.md) | [한국어](README-ko.md)

</div>

观我 (ScaleMe) est une application iOS native de suivi du poids et de la composition corporelle, pour les particuliers et les familles. Connectez une balance Bluetooth compatible ou saisissez vos mesures, puis consultez l’historique et les tendances par profil, appareil et période.

Aucun compte n’est nécessaire. Profils, réglages des appareils et mesures sont stockés sur l’appareil, sans envoi aux serveurs du développeur ni synchronisation cloud propre à l’application. L’accès à Apple Santé et les imports et exports de fichiers sont activés ou effectués par l’utilisateur.

<div align="center">

<a href="https://apps.apple.com/app/id6808930548">
  <img src="../../Design/Download/AppStoreBanner.png" width="100%" alt="Présentation de ScaleMe et téléchargement sur l’App Store">
</a>

</div>

## Principales fonctionnalités

### Mesures et enregistrements

- Détecter et associer des balances Bluetooth compatibles, afficher la progression et les données disponibles, puis enregistrer les mesures stables.
- Saisir le poids, choisir la date et l’heure et ajouter, si nécessaire, les valeurs de composition corporelle affichées par l’appareil, y compris pour des mesures passées.
- Consulter les détails, réattribuer une mesure à un profil ou la supprimer. Les protocoles compatibles permettent de lire l’historique de la balance, d’associer les profils et de supprimer les doublons.
- Les mesures en direct sont enregistrées dans un fichier local avant de devenir des enregistrements définitifs et de déclencher le partage Santé activé. Un échec affiche l’état non enregistré et permet de réessayer.

### Profils familiaux et tendances

- Créer plusieurs profils, gérer plusieurs appareils et consulter séparément les mesures de chaque personne.
- Choisir et ordonner les indicateurs sur l’accueil, avec leurs dernières valeurs, leur signification et les plages de référence applicables.
- Filtrer les tendances par profil, appareil, période et indicateur, puis explorer les changements avec les graphiques et l’historique.
- Widgets de tendances petits, moyens et grands sur l’écran d’accueil, chacun avec ses propres réglages d’indicateur, période, appareil, profil et affichage.

### Gestion des données et Apple Santé

- Importer et exporter les réglages et mesures séparément ou ensemble en JSON, et supprimer les données locales.
- Lire facultativement le poids et le taux de masse grasse d’Apple Santé dans votre propre profil, et y écrire les nouvelles mesures admissibles.
- Les interrupteurs de synchronisation et les autorisations système sont gérés séparément. Les mesures Bluetooth, la saisie manuelle et les tendances restent disponibles sans synchronisation.

### Interface et accessibilité

- Chinois simplifié et traditionnel, anglais, japonais, français, allemand, espagnol, portugais, russe et coréen ; langue du système ou choix dans l’application.
- Thèmes standard et adapté aux déficiences de perception des couleurs, avec apparences claire, sombre ou système.
- VoiceOver pour les états de mesure, graphiques, menus et formulaires, avec prise en charge de Dynamic Type et Réduire les animations. Voir le périmètre réel de la [validation de l’accessibilité](../Accessibility.md).
- Des données familiales simulées permettent d’explorer l’interface sans balance. Les modifications de ces enregistrements n’affectent pas les mesures réelles ; les données prédéfinies sont rétablies au prochain lancement.

## Compatibilité des appareils

Le projet implémente l’analyse des caractéristiques standard Bluetooth SIG de poids et de composition corporelle, ainsi que l’analyse des annonces ou les sessions de mesure GATT de plusieurs protocoles fabricants. Les fonctions et niveaux de validation varient : une marque ne garantit pas la compatibilité de tous ses modèles.

- Détecter un appareil, reconnaître son nom ou enregistrer un protocole ne garantit pas la prise en charge des mesures.
- Les tests sur échantillons valident l’analyse des données, pas le fonctionnement de bout en bout avec un iPhone et une balance réelle.
- Mesures en direct, composition corporelle, lecture de l’historique et configuration de l’authentification dépendent du protocole. Les champs non confirmés ne sont pas enregistrés comme indicateurs connus.
- Des règles de communication déclaratives conformes peuvent être importées depuis des fichiers JSON locaux. L’application ne télécharge pas de protocoles depuis des URL distantes.

Voir la [matrice de prise en charge des protocoles](../BluetoothProtocolSupport.md) pour les capacités, niveaux de validation et sources de recherche, et les [règles de communication externes](../ExternalCommunicationRules.md) pour le format d’extension.

## Indicateurs et estimations

L’application distingue les valeurs brutes de l’appareil de ses propres calculs. Le poids, la composition corporelle fournie par l’appareil, l’IMC calculé à partir du profil et les estimations conditionnelles ont des sources et des domaines d’application différents.

Pour les balances à composition corporelle reconnues, les valeurs de l’appareil ou du protocole sont prioritaires. Les valeurs manquantes ne font l’objet d’estimations expérimentales qu’avec une impédance principale valide, les informations du profil et les conditions requises par le modèle. Les balances de poids seules, les saisies manuelles et les imports Apple Santé ne déclenchent pas ces estimations par défaut. Sans impédance principale, l’IMC ne la remplace pas pour estimer la composition corporelle manquante.

Les résultats calculés sont enregistrés avec chaque mesure, séparément des valeurs brutes. Modifier le profil ne recalcule pas automatiquement l’historique ; réattribuer une mesure à un autre profil le fait. Les estimations ne sont pas écrites dans Apple Santé. Les tranches d’âge des modèles, les hypothèses d’adaptation aux appareils et les règles empiriques sont limitées ; ces estimations ne sont ni les algorithmes officiels des fabricants ni des mesures cliniques.

La section d’information sur les données et les pages de calcul des indicateurs présentent formules, sources et domaines d’application. Voir [données, synchronisation et confidentialité](../DataAndPrivacy.md) pour les détails techniques. Les résultats de composition corporelle servent à observer des tendances, pas au diagnostic, au traitement ou aux décisions médicales.

<a id="data-storage-and-privacy"></a>

## Stockage et confidentialité

### Stockage sur l’appareil

Profils, réglages des appareils et mesures sont conservés dans des fichiers JSON versionnés dans le bac à sable de l’application. Réglages et mesures sont séparés et utilisent iOS Complete File Protection. Les secrets d’association et d’authentification sont conservés dans le trousseau système Keychain.

Les widgets lisent un instantané compact des tendances via un App Group local. L’instantané est chiffré avec AES-GCM et ses clés sont gérées dans un Keychain partagé. Il s’agit d’un partage entre l’application et son extension sur le même appareil.

L’application ne comporte ni comptes, ni publicité, ni service de remontée de données analytiques. Elle ne transmet pas les profils et mesures de santé aux serveurs du développeur et ne synchronise pas ces données en temps réel via iCloud.

### Transferts contrôlés par l’utilisateur

- **Sauvegardes système** : les réglages et mesures peuvent être inclus dans les sauvegardes de l’appareil activées par l’utilisateur. Le système gère sauvegarde et restauration.
- **Apple Santé** : lecture et écriture désactivées par défaut, avec configuration et autorisation nécessaires. Les lectures vont uniquement dans votre propre profil ; les écritures concernent vos nouvelles mesures stables provenant des appareils réels sélectionnés. Historiques importés, saisies manuelles, données simulées et estimations ne sont pas écrits dans Santé. Désactiver la synchronisation ne supprime pas les données déjà écrites ou importées.
- **Importation et exportation de fichiers** : déclenchées par l’utilisateur. Le JSON exporté est du texte non chiffré pouvant contenir profils, informations d’appareils et mesures. L’utilisateur choisit l’emplacement et les destinataires.
- **Exportation de diagnostics** : collectés et exportés à l’initiative de l’utilisateur, ils peuvent contenir des identifiants d’appareils et des charges utiles de mesure. Les fichiers originaux ne doivent pas être partagés publiquement.

Voir la [politique de confidentialité](../PrivacyPolicy.md) et le [guide de validation HealthKit](../AppReviewHealthKit.md) pour les détails, autorisations et procédures de validation.

## Technologies et structure du projet

iOS 17 minimum, avec Swift, SwiftUI, Charts, CoreBluetooth, HealthKit, WidgetKit et CryptoKit. Interface, calculs métier, analyse des protocoles et services système sont séparés par responsabilité.

```text
ScaleMe/
├── App/              # Entrée, navigation, démarrage et état global
├── Core/             # Fondations transversales, dont la localisation
├── Domain/           # Modèles métier, calculs et analyse des tendances
├── Infrastructure/   # Bluetooth, persistance, santé, diagnostics, export widgets
├── Features/         # Accueil, mesures, tendances, appareils et réglages
├── Shared/           # Système de design et composants partagés
└── Resources/        # Assets, String Catalog et configuration
ScaleMeWidget/        # Widgets de tendances sur l’écran d’accueil
ScaleMeWidgetShared/  # Contrats de données et stockage partagés app/widgets
Docs/                # Documentation d’implémentation et de validation
└── readme/           # Traductions intégrales du README
Tests/Smoke/         # Vérifications déterministes des protocoles, calculs et langues
Tools/               # Outils de développement et de génération de ressources
```

Voir [architecture et implémentation](../Architecture.md) pour les couches, transitions d’état et le pipeline Bluetooth.

## Exécuter le projet

1. Ouvrir `ScaleMe.xcodeproj` dans Xcode 26 ou ultérieur et sélectionner le scheme `ScaleMe`.
2. Exécuter dans le simulateur et activer les données simulées dans Réglages → Gestion des données pour explorer profils, appareils, mesures et graphiques.
3. Pour tester les mesures Bluetooth réelles, configurer une équipe de développement, installer sur un iPhone et autoriser Bluetooth lors de la recherche d’appareils.
4. Pour tester les widgets, configurer des capacités App Groups et Keychain Sharing correspondantes pour l’application et l’extension `ScaleMeWidget`.

Le simulateur et les tests automatisés ne remplacent pas la validation de Bluetooth, HealthKit et des modèles de balances sur du matériel réel. Voir [développement et validation](../Development.md) pour les prérequis, commandes de compilation et points d’entrée des tests.

## Documentation et contributions

- [Index de la documentation](../README.md)
- [Architecture et implémentation](../Architecture.md)
- [Matrice de prise en charge des protocoles](../BluetoothProtocolSupport.md)
- [Données, synchronisation et confidentialité](../DataAndPrivacy.md)
- [Développement et validation](../Development.md)
- [Conventions de développement des agents](../../AGENTS.md)

Le nom chinois est « 观我 » ; le nom anglais et celui du projet Xcode sont « ScaleMe ». Le logo de référence est [`Design/Logo/logo.svg`](../../Design/Logo/logo.svg). Les marques tierces citées décrivent la compatibilité ou les sources techniques et n’impliquent aucun soutien des fabricants.

## Licence

La distribution du code source du projet dans son ensemble relève de la **[GNU GPL v3 ou ultérieure](../../LICENSE)** (`GPL-3.0-or-later`). Contributions originales : Copyright (C) 2026 bugwz. Les parties tierces conservent leurs droits et licences d’origine ; voir la [notice du projet](../../NOTICE) et les [licences et mentions tierces](../../LICENSES/README.md).
