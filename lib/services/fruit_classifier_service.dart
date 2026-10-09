import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class FruitClassifierService {
  // ⚠️ IMPORTANT: Change cette URL selon ton environnement
  // Pour émulateur Android: 'http://10.0.2.2:5001'
  // Pour appareil physique: 'http://YOUR_COMPUTER_IP:5001'
  // Pour iOS simulator: 'http://localhost:5001'
  // Pour Flutter Web: 'http://localhost:5001'

  // ✅ URL CORRECTE avec votre IP et le protocole HTTP
  static const String _baseUrl = 'http://172.20.10.5:5001';

  bool _modelLoaded = false;
  List<String> _classNames = [];

  bool get isLoaded => _modelLoaded;
  List<String> get classNames => _classNames;

  // 🔧 FIX 2: Vérification améliorée du serveur avec /health endpoint
  Future<void> loadModel() async {
    try {
      print('🔄 Tentative de connexion à $_baseUrl...');

      // Utiliser l'endpoint /health comme dans test_predictions.py
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _modelLoaded = data['model_loaded'] == true;

        if (_modelLoaded) {
          // Récupérer les classes disponibles
          await _loadClasses();
          print('✅ Connexion au serveur réussie');
          print('   Modèle chargé: $_modelLoaded');
          print('   Classes: ${_classNames.length}');
        } else {
          throw Exception('Modèle non chargé sur le serveur');
        }
      } else {
        throw Exception(
          'Serveur non accessible (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      print('❌ Erreur de connexion au serveur: $e');
      print('💡 Vérifications à faire:');
      print('   1. Le serveur Flask est-il démarré? (python app.py)');
      print('   2. L\'URL est-elle correcte? ($_baseUrl)');
      print('   3. Êtes-vous sur le même réseau?');
      _modelLoaded = false;
      rethrow;
    }
  }

  // 🔧 FIX 3: Récupération des classes depuis le serveur
  Future<void> _loadClasses() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/classes'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _classNames = List<String>.from(data['classes']);
      }
    } catch (e) {
      print('⚠️ Impossible de charger les classes: $e');
    }
  }

  // 🔧 FIX 4: Format de réponse corrigé selon l'API Flask
  Future<Map<String, dynamic>> classifyImage(XFile imageFile) async {
    if (!_modelLoaded) {
      throw Exception(
        'Le serveur n\'est pas accessible. Appelez loadModel() d\'abord.',
      );
    }

    try {
      print('📤 Envoi de l\'image: ${imageFile.name}');

      // Créer la requête multipart
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/predict'),
      );

      // Lire les bytes de l'image
      final bytes = await imageFile.readAsBytes();
      print('   Taille: ${(bytes.length / 1024).toStringAsFixed(1)} KB');

      // Ajouter l'image
      request.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: imageFile.name),
      );

      // Envoyer la requête
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        // L'API Flask retourne:
        // {
        //   "prediction": {"class": "...", "confidence": ..., "percentage": ...},
        //   "top_3": [{"class": "...", "confidence": ..., "percentage": ...}],
        //   "all_predictions": {"class1": prob1, ...}
        // }

        final prediction = result['prediction'];
        final allPredictions = Map<String, double>.from(
          (result['all_predictions'] as Map).map(
            (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
          ),
        );

        print('✅ Prédiction reçue:');
        print('   Classe: ${prediction['class']}');
        print('   Confiance: ${prediction['percentage'].toStringAsFixed(1)}%');

        return {
          'label': prediction['class'] as String,
          'confidence': (prediction['confidence'] as num).toDouble(),
          'percentage': (prediction['percentage'] as num).toDouble(),
          'allPredictions': allPredictions,
          'top3': result['top_3'], // Inclure le top 3
        };
      } else {
        final error = jsonDecode(response.body);
        throw Exception(
          'Erreur serveur (${response.statusCode}): ${error['error']}',
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la classification: $e');
      rethrow;
    }
  }

  // 🔧 FIX 5: Méthode améliorée pour obtenir le top N
  List<Map<String, dynamic>> getTopPredictions(
    Map<String, double> allPredictions,
    int topN,
  ) {
    var sortedPredictions = allPredictions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedPredictions
        .take(topN)
        .map(
          (e) => {
            'label': e.key,
            'confidence': e.value,
            'percentage': e.value * 100,
          },
        )
        .toList();
  }

  // 🆕 Méthode utilitaire pour tester la connexion
  Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 🆕 Obtenir les informations du serveur
  Future<Map<String, dynamic>> getServerInfo() async {
    try {
      final response = await http
          .get(Uri.parse(_baseUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Impossible d\'obtenir les infos du serveur');
      }
    } catch (e) {
      print('❌ Erreur: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    _modelLoaded = false;
    _classNames.clear();
  }
}
