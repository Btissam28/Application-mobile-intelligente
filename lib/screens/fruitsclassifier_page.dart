import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/fruit_classifier_service.dart';

class FruitsClassifierPage extends StatefulWidget {
  const FruitsClassifierPage({super.key});

  @override
  State<FruitsClassifierPage> createState() => _FruitsClassifierPageState();
}

class _FruitsClassifierPageState extends State<FruitsClassifierPage> {
  final FruitClassifierService _classifierService = FruitClassifierService();
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImageFile;
  Uint8List? _imageBytes;
  Map<String, dynamic>? _result;
  bool _isLoading = false;
  bool _modelLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    setState(() => _isLoading = true);
    try {
      await _classifierService.loadModel();
      setState(() => _modelLoaded = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Connexion au serveur réussie!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Erreur: Serveur non accessible\n💡 Démarre le serveur Flask!',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndClassifyImage(ImageSource source) async {
    if (!_modelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modèle en cours de chargement...')),
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      setState(() {
        _selectedImageFile = image;
        _isLoading = true;
        _result = null;
      });

      // Lire les bytes de l'image
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });

      // Classifier automatiquement
      final result = await _classifierService.classifyImage(image);

      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getFruitEmoji(String fruitName) {
    const emojiMap = {
      'apple': '🍎',
      'banana': '🍌',
      'corn': '🌽',
      'cucumber': '🥒',
      'grapes': '🍇',
      'kiwi': '🥝',
      'lemon': '🍋',
      'mango': '🥭',
      'orange': '🍊',
      'pear': '🍐',
      'pineapple': '🍍',
      'tomato': '🍅',
      'watermelon': '🍉',
    };
    return emojiMap[fruitName.toLowerCase()] ?? '🍏';
  }

  Widget _buildUploadSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.cloud_upload, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Charger une photo de fruit',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Prenez une photo ou choisissez depuis votre galerie',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _modelLoaded && !_isLoading
                        ? () => _pickAndClassifyImage(ImageSource.camera)
                        : null,
                    icon: const Icon(Icons.camera_alt, size: 28),
                    label: const Text('Caméra'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _modelLoaded && !_isLoading
                        ? () => _pickAndClassifyImage(ImageSource.gallery)
                        : null,
                    icon: const Icon(Icons.photo_library, size: 28),
                    label: const Text('Galerie'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    if (_imageBytes == null && _result == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_imageBytes != null)
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 20),
            if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      _getFruitEmoji(_result!['label']),
                      style: const TextStyle(fontSize: 60),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'C\'est un(e):',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (_result!['label'] as String).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Confiance: ${((_result!['confidence'] as double) * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Autres possibilités:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...(_classifierService
                  .getTopPredictions(
                    _result!['allPredictions'] as Map<String, double>,
                    4,
                  )
                  .skip(1)
                  .map((pred) {
                    final predLabel = pred['label'] as String;
                    final predConf = pred['confidence'] as double;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Text(
                            _getFruitEmoji(predLabel),
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  predLabel,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: predConf,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.green.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${(predConf * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList()),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedImageFile = null;
                  _imageBytes = null;
                  _result = null;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Analyser un autre fruit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🍎 Détection de Fruits'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.withOpacity(0.1), Colors.white],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.green),
                    SizedBox(height: 16),
                    Text('Analyse en cours...', style: TextStyle(fontSize: 16)),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (!_modelLoaded)
                      Card(
                        color: Colors.orange[100],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  if (_isLoading)
                                    const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.orange,
                                    )
                                  else
                                    const Icon(
                                      Icons.warning,
                                      color: Colors.orange,
                                    ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Text(
                                      'Connexion au serveur...',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '💡 Assure-toi que le serveur Flask est démarré:\npython flask_server.py',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_imageBytes == null && _result == null)
                      _buildUploadSection()
                    else
                      _buildResultSection(),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _classifierService.dispose();
    super.dispose();
  }
}
