import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _ragEnabled = true;
  int _totalChunks = 0;
  int _totalDocuments = 0;
  String _apiStatus = 'Checking...';
  String _ollamaStatus = 'unknown';
  String _embeddingModel = 'unknown';

  // 🔧 IMPORTANT: Remplacez par l'IP de votre machine
  static const String apiUrl = 'http://172.20.10.5:8000';

  @override
  void initState() {
    super.initState();
    _checkApiHealth();
    _loadStats();
  }

  Future<void> _checkApiHealth() async {
    try {
      print('🔍 Checking FastAPI health at $apiUrl/health');
      final response = await http
          .get(
            Uri.parse('$apiUrl/health'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ FastAPI Health Response: $data');
        setState(() {
          _apiStatus = 'Connected ✅';
          _ollamaStatus = data['ollama'] ?? 'unknown';
          _totalChunks = data['rag_system']?['documents'] ?? 0;
        });
        _showSuccess('Connected to FastAPI!');
      } else {
        setState(() {
          _apiStatus = 'Error ❌';
        });
      }
    } catch (e) {
      print('❌ FastAPI connection error: $e');
      setState(() {
        _apiStatus = 'Failed to connect';
      });
      _showError(
        'Cannot connect to FastAPI.\nPlease ensure:\n1. FastAPI is running on port 8000\n2. Correct IP: $apiUrl\n3. Run: python main.py',
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/api/documents/stats'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📊 Stats loaded: $data');
        setState(() {
          _totalChunks = data['total_chunks'] ?? 0;
          _totalDocuments = data['total_documents'] ?? 0;
          _embeddingModel = data['embedding_model'] ?? 'unknown';
        });
      }
    } catch (e) {
      print('⚠️ Stats error: $e');
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Construire l'historique de conversation (limité aux 4 derniers)
    final history = _messages
        .where((m) => m.text.isNotEmpty && !m.isUser)
        .take(4)
        .map((m) => {'role': 'assistant', 'content': m.text})
        .toList();

    // Préparer le payload pour FastAPI
    final requestBody = {
      'message': text,
      'conversation_history': history,
      'use_rag': _ragEnabled,
      'top_k_docs': 3,
      'model': 'llama3.2:3b',
      'temperature': 0.7,
      'max_tokens': 1024,
    };

    print('📤 Sending to FastAPI: ${json.encode(requestBody)}');
    print('⏱️ Waiting for response (timeout: 10min)...');

    // 🔥 TIMEOUT AUGMENTÉ À 10 MINUTES (600 secondes)
    final response = await http
        .post(
          Uri.parse('$apiUrl/api/chat'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode(requestBody),
        )
        .timeout(const Duration(seconds: 600));

    print('📥 FastAPI Response Status: ${response.statusCode}');
    print('📥 FastAPI Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final assistantResponse = data['response'] ?? 'No response';
      final sources = data['sources'] ?? [];

      setState(() {
        _messages.add(
          ChatMessage(
            text: assistantResponse,
            isUser: false,
            sources: List<String>.from(sources),
          ),
        );
        _isLoading = false;
      });

      if (sources.isNotEmpty) {
        print('📚 Sources used: $sources');
      }
    } else {
      final errorBody = response.body;
      _showError('Server Error: ${response.statusCode}\n$errorBody');
      setState(() {
        _messages.add(
          ChatMessage(
            text: '❌ Error: Server returned status ${response.statusCode}',
            isUser: false,
          ),
        );
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  Future<void> _uploadDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
      allowMultiple: true,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      // Créer la requête multipart
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiUrl/api/documents/upload'),
      );

      // Ajouter tous les fichiers
      for (var file in result.files) {
        if (file.bytes != null) {
          print('📄 Adding file: ${file.name} (${file.size} bytes)');
          request.files.add(
            http.MultipartFile.fromBytes(
              'files',
              file.bytes!,
              filename: file.name,
            ),
          );
        }
      }

      print('📤 Uploading ${result.files.length} file(s)...');

      // Envoyer la requête avec timeout augmenté
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 300),
      );
      var response = await http.Response.fromStream(streamedResponse);

      print('📥 Upload response: ${response.statusCode}');
      print('📥 Upload body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          await _loadStats();
          _showSuccess(
            '✅ ${data['message']}\n'
            '📊 Total chunks: ${data['stats']['total_chunks']}',
          );
        } else {
          _showError('❌ Error: ${data['message']}');
        }
      } else {
        _showError('❌ Upload failed: ${response.statusCode}\n${response.body}');
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearDocuments() async {
    setState(() {
      _isLoading = true;
    });

    final response = await http.delete(
      Uri.parse('$apiUrl/api/documents/clear'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await _loadStats();
      _showSuccess(data['message'] ?? '✅ Documents cleared');
    } else {
      _showError('Error clearing documents: ${response.statusCode}');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
    _showSuccess('Chat cleared');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎓 EMSI Chatbot RAG'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _checkApiHealth();
              _loadStats();
            },
            tooltip: 'Refresh Connection',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('⚠️ Clear All Documents'),
                  content: const Text(
                    'Are you sure you want to clear all indexed documents?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _clearDocuments();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Clear Documents',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Statistics',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('📊 System Statistics'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatRow('API Status', _apiStatus),
                        _buildStatRow('Ollama Status', _ollamaStatus),
                        const Divider(),
                        _buildStatRow('Documents', '$_totalDocuments'),
                        _buildStatRow('Text Chunks', '$_totalChunks'),
                        _buildStatRow('Embedding Model', _embeddingModel),
                        const Divider(),
                        _buildStatRow(
                          'RAG',
                          _ragEnabled ? 'Enabled ✅' : 'Disabled ❌',
                        ),
                        _buildStatRow('Model', 'llama3.2:3b'),
                        _buildStatRow('Timeout', '10 minutes'),
                        _buildStatRow('Server', apiUrl),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _apiStatus.contains('✅') ? Colors.green[50] : Colors.red[50],
            child: Row(
              children: [
                Icon(
                  _apiStatus.contains('✅') ? Icons.check_circle : Icons.error,
                  color: _apiStatus.contains('✅') ? Colors.green : Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FastAPI: $_apiStatus | Ollama: $_ollamaStatus',
                    style: TextStyle(
                      color: _apiStatus.contains('✅')
                          ? Colors.green[700]
                          : Colors.red[700],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_totalChunks > 0)
                  Chip(
                    label: Text('$_totalChunks chunks'),
                    backgroundColor: Colors.blue[100],
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
              ],
            ),
          ),

          // Messages area
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome to EMSI Chatbot!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload documents and start chatting',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _uploadDocument,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload Documents'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _messages[index];
                    },
                  ),
          ),

          // Loading indicator avec meilleur feedback
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Flexible(
                    child: Text(
                      'Thinking... (This may take up to 10 minutes)',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

          // Input area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.upload_file),
                  onPressed: _isLoading ? null : _uploadDocument,
                  tooltip: 'Upload documents',
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: _ragEnabled,
                      onChanged: (value) {
                        setState(() {
                          _ragEnabled = value;
                        });
                        _showSuccess(
                          _ragEnabled ? 'RAG enabled' : 'RAG disabled',
                        );
                      },
                    ),
                    Text(
                      'RAG',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask your question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _isLoading ? null : _sendMessage,
                    enabled: !_isLoading,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading
                      ? null
                      : () => _sendMessage(_messageController.text),
                  color: Theme.of(context).primaryColor,
                  disabledColor: Colors.grey,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _clearChat,
        tooltip: 'Clear chat',
        child: const Icon(Icons.clear_all),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final List<String>? sources;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.sources,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    size: 20,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue[600] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 20,
                    color: Colors.green,
                  ),
                ),
              ],
            ],
          ),
          if (sources != null && sources!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: sources!
                    .map(
                      (source) => Chip(
                        label: Text(
                          source,
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: Colors.blue[50],
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
