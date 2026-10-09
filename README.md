# Smart App Bakkar

Application Flutter proposant une authentification Firebase, un classificateur de fruits à partir d'une photo et un chatbot connecté à une API avec recherche dans des documents (RAG).

L'application mobile constitue le frontend du projet. Les serveurs Python de classification et de chatbot ne sont pas inclus dans ce dépôt : ils doivent être installés et démarrés séparément pour utiliser ces fonctionnalités.

## Fonctionnalités

- **Connexion et inscription** par adresse e-mail et mot de passe avec Firebase Authentication.
- **Accueil** avec un menu d'accès aux fonctionnalités principales.
- **Classification de fruits** : sélection d'une photo dans la galerie ou prise avec la caméra, envoi au serveur Flask, puis affichage de la prédiction, de sa confiance et d'autres résultats possibles.
- **Chatbot EMSI** : envoi de messages à un serveur FastAPI configuré pour utiliser Ollama et la RAG. L'interface permet aussi d'importer des fichiers PDF/TXT et de gérer les documents indexés.

## Architecture du dépôt

```text
lib/
	main.dart                         Initialisation Firebase et routes Flutter
	firebase_options.dart             Configuration Firebase par plateforme
	screens/
		login_page.dart                 Connexion
		register_page.dart              Création de compte
		home_page.dart                  Accueil et navigation
		fruitsclassifier_page.dart      Interface du classificateur
		chatbot_page.dart               Interface du chatbot et gestion des documents
	services/
		fruit_classifier_service.dart   Appels HTTP au serveur de classification
assets/
	images/                           Images de l'application
	model.tflite                      Modèle fourni comme asset
	labels.txt                        Labels fournis comme asset
android/, ios/, web/, windows/      Projets hôtes Flutter
test/                               Tests Flutter
```

`assets/model.tflite` et `assets/labels.txt` sont déclarés comme assets Flutter. Dans l'implémentation actuelle, la classification affichée par l'application est toutefois demandée au serveur Flask : le service Flutter envoie l'image à `/predict` et ne charge pas directement ce modèle.

## Prérequis

- Flutter SDK avec une version de Dart compatible avec `^3.9.2` (voir `pubspec.yaml`).
- Un appareil ou émulateur pris en charge par Flutter.
- Un projet Firebase configuré pour les plateformes utilisées, avec Firebase Authentication activé pour l'e-mail et le mot de passe.
- Pour la classification : le serveur Flask correspondant au protocole décrit ci-dessous.
- Pour le chatbot : le serveur FastAPI, Ollama et le système RAG correspondant aux routes appelées par l'application.

## Installation et lancement

Depuis la racine du dépôt :

```bash
flutter pub get
flutter run
```

L'application démarre sur l'écran de connexion. Crée un compte depuis **Register**, puis connecte-toi pour accéder à l'accueil.

Commandes utiles :

```bash
flutter analyze
flutter test
```

## Configuration Firebase

L'initialisation se fait dans `lib/main.dart` avec les options de `lib/firebase_options.dart`. Vérifie que les identifiants correspondent à ton projet Firebase et que l'authentification par e-mail/mot de passe est activée dans la console Firebase.

Les options fournies dans le dépôt couvrent Android, iOS, Web et Windows. Les configurations macOS et Linux ne sont pas présentes dans `firebase_options.dart`; ces plateformes nécessitent une configuration Firebase supplémentaire avant exécution.

## Services backend requis

Les adresses des serveurs sont actuellement inscrites en dur dans le code. Remplace-les par des adresses joignables depuis l'appareil ou l'émulateur avant de lancer les fonctionnalités concernées.

### Classification de fruits

Le service [lib/services/fruit_classifier_service.dart](lib/services/fruit_classifier_service.dart) utilise actuellement `http://172.20.10.5:5001` et attend les routes suivantes :

- `GET /health` : état du serveur et indication `model_loaded`.
- `GET /classes` : liste des classes reconnues.
- `POST /predict` : image envoyée en multipart sous le champ `image`; la réponse attend notamment `prediction`, `top_3` et `all_predictions`.

L'écran affiche une indication invitant à démarrer le serveur avec `python flask_server.py`, mais le code de ce serveur n'est pas présent dans ce dépôt. L'adresse IP privée actuelle est propre à un réseau local et devra probablement être modifiée. Pour l'émulateur Android, le code du service suggère `10.0.2.2` pour joindre la machine hôte; sur un appareil physique, utilise l'adresse IP locale de l'ordinateur et le même réseau.

### Chatbot

L'écran [lib/screens/chatbot_page.dart](lib/screens/chatbot_page.dart) utilise actuellement `http://172.20.10.5:8000`. Il appelle :

- `GET /health` et `GET /api/documents/stats` au démarrage.
- `POST /api/chat` pour envoyer un message (modèle demandé : `llama3.2:3b`, RAG activée par défaut).
- `POST /api/documents/upload` pour importer des fichiers PDF/TXT.
- `DELETE /api/documents/clear` pour supprimer les documents indexés.

Le message de diagnostic de l'application indique `python main.py` comme commande de démarrage du backend, mais son code n'est pas inclus ici. L'API doit être accessible sur le réseau de l'appareil. Les appels HTTP en clair peuvent aussi nécessiter une configuration spécifique selon la plateforme et l'environnement de déploiement.

## Dépendances Flutter principales

- `firebase_core` et `firebase_auth` : initialisation Firebase et authentification.
- `http` : communication avec les API Python.
- `image_picker` : capture ou sélection d'images.
- `file_picker` : import de documents PDF et TXT.
- `image` : traitement d'images côté Flutter.

La liste complète et les versions sont définies dans `pubspec.yaml`.

## Tests

Le dossier `test/` contient actuellement un test de démarrage Flutter issu du template initial. Il vérifie encore un compteur de démonstration et ne correspond pas aux écrans de l'application; les tests fonctionnels du parcours d'authentification, de classification et du chatbot restent à ajouter.

## Limites connues

- Les deux URL de backend sont des adresses IP locales codées en dur et doivent être adaptées à l'environnement.
- Les backends Flask et FastAPI/Ollama ne sont pas fournis dans ce dépôt.
- Les actions **Profile**, **Settings** et **Logout** du menu d'accueil ne sont pas encore implémentées fonctionnellement.
- Le test widget présent est encore celui du template Flutter.
