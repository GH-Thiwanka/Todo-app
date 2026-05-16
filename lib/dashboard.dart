import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<dynamic> _tasks = [];

  final TextEditingController _taskController = TextEditingController();

  bool _isLoading = true;

  File? _selectedImage;

  final ImagePicker _picker = ImagePicker();

  final TextStyle _gaeguStyle = const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    fontFamily: 'Gaegu',
    color: Colors.black,
  );

  final String baseUrl =
      'https://jbaodzbzwa.execute-api.us-east-1.amazonaws.com/prod/tasks/';

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  // PICK IMAGE
  Future<void> _pickImage() async {
    final XFile? pickedImage = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedImage != null) {
      setState(() {
        _selectedImage = File(pickedImage.path);
      });
    }
  }

  // CONVERT IMAGE TO BASE64
  Future<String?> _convertImageToBase64(File? imageFile) async {
    if (imageFile == null) return null;

    final bytes = await imageFile.readAsBytes();

    return base64Encode(bytes);
  }

  // FETCH TASKS
  Future<void> _fetchTasks() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

      debugPrint("FETCH STATUS: ${response.statusCode}");
      debugPrint("FETCH BODY: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _tasks = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");

      setState(() => _isLoading = false);
    }
  }

  // CREATE TASK
  Future<void> _postTask() async {
    final taskText = _taskController.text.trim();

    if (taskText.isEmpty) return;

    String? base64Image = await _convertImageToBase64(_selectedImage);

    try {
      final response = await http.post(
        Uri.parse(baseUrl),

        headers: {'Content-Type': 'application/json'},

        body: jsonEncode({
          "taskId": DateTime.now().millisecondsSinceEpoch.toString(),

          "taskName": taskText,

          "status": "pending",

          "image": base64Image ?? "",
        }),
      );

      debugPrint("POST STATUS: ${response.statusCode}");
      debugPrint("POST BODY: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        _taskController.clear();

        setState(() {
          _selectedImage = null;
        });

        _fetchTasks();
      }
    } catch (e) {
      debugPrint("Post Error: $e");
    }
  }

  // UPDATE TASK
  Future<void> _updateTask(
    String id,
    String newTitle,
    String status,
    String? imageBase64,
  ) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl$id"),

        headers: {'Content-Type': 'application/json'},

        body: jsonEncode({
          "taskName": newTitle,
          "status": status,

          // IMPORTANT
          "image": imageBase64 ?? "",
        }),
      );

      debugPrint("UPDATE STATUS: ${response.statusCode}");
      debugPrint("UPDATE BODY: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchTasks();
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }

  // DELETE TASK
  Future<void> _deleteTask(String id) async {
    try {
      final response = await http.delete(Uri.parse("$baseUrl$id"));

      debugPrint("DELETE STATUS: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 204) {
        _fetchTasks();
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  // EDIT DIALOG
  Future<void> _showEditDialog(
    String id,
    String currentTitle,
    String status,
    String? imageUrl,
  ) async {
    final TextEditingController editController = TextEditingController(
      text: currentTitle,
    );

    File? newSelectedImage;

    return showDialog(
      context: context,

      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Task', style: _gaeguStyle),

              content: SizedBox(
                width: double.maxFinite,

                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      // EXISTING IMAGE
                      if (imageUrl != null &&
                          imageUrl!.isNotEmpty &&
                          newSelectedImage == null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),

                              child: SizedBox(
                                height: 180,
                                width: double.infinity,

                                child: Image.network(
                                  imageUrl!,
                                  fit: BoxFit.cover,

                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 180,
                                      color: Colors.grey[300],

                                      child: const Icon(Icons.image, size: 50),
                                    );
                                  },
                                ),
                              ),
                            ),

                            // DELETE IMAGE
                            Positioned(
                              top: 10,
                              right: 10,

                              child: GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    imageUrl = null;
                                  });
                                },

                                child: Container(
                                  padding: const EdgeInsets.all(6),

                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),

                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                      // NEW IMAGE
                      if (newSelectedImage != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),

                              child: SizedBox(
                                height: 180,
                                width: double.infinity,

                                child: Image.file(
                                  newSelectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),

                            Positioned(
                              top: 10,
                              right: 10,

                              child: GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    newSelectedImage = null;
                                  });
                                },

                                child: Container(
                                  padding: const EdgeInsets.all(6),

                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),

                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 20),

                      // ADD IMAGE
                      if (imageUrl == null && newSelectedImage == null)
                        ElevatedButton.icon(
                          onPressed: () async {
                            final XFile? picked = await _picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 70,
                            );

                            if (picked != null) {
                              setDialogState(() {
                                newSelectedImage = File(picked.path);
                              });
                            }
                          },

                          icon: const Icon(Icons.image),

                          label: const Text("Add Image"),
                        ),

                      // CHANGE IMAGE
                      if (imageUrl != null || newSelectedImage != null)
                        TextButton.icon(
                          onPressed: () async {
                            final XFile? picked = await _picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 70,
                            );

                            if (picked != null) {
                              setDialogState(() {
                                newSelectedImage = File(picked.path);
                              });
                            }
                          },

                          icon: const Icon(Icons.edit),

                          label: const Text("Change Image"),
                        ),

                      const SizedBox(height: 20),

                      // TITLE
                      TextField(
                        controller: editController,

                        style: _gaeguStyle.copyWith(fontSize: 18),

                        decoration: const InputDecoration(
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              actions: [
                // UPDATE
                TextButton(
                  onPressed: () async {
                    String? imageBase64;

                    // NEW IMAGE
                    if (newSelectedImage != null) {
                      imageBase64 = await _convertImageToBase64(
                        newSelectedImage,
                      );
                    }

                    // KEEP OLD IMAGE
                    if (newSelectedImage == null &&
                        imageUrl != null &&
                        imageUrl!.isNotEmpty) {
                      imageBase64 = imageUrl;
                    }

                    // REMOVE IMAGE
                    if (imageUrl == null && newSelectedImage == null) {
                      imageBase64 = "";
                    }

                    await _updateTask(
                      id,
                      editController.text,
                      status,
                      imageBase64,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },

                  child: const Text(
                    'Update',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),

                // DELETE TASK
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),

                  onPressed: () async {
                    await _deleteTask(id);

                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },

                  child: const Text(
                    'Delete Task',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),

              child: Column(
                children: [
                  const SizedBox(height: 50),

                  Text('My silly little tasks', style: _gaeguStyle),

                  const SizedBox(height: 50),

                  // INPUT
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _taskController,

                          style: _gaeguStyle,

                          decoration: InputDecoration(
                            hintText: 'add new task',

                            hintStyle: _gaeguStyle.copyWith(
                              color: Colors.black54,
                            ),

                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.green,
                                width: 3,
                              ),
                            ),

                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.green,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 15),

                      // IMAGE BUTTON
                      GestureDetector(
                        onTap: _pickImage,

                        child: const Icon(
                          Icons.image,
                          size: 35,
                          color: Colors.green,
                        ),
                      ),

                      const SizedBox(width: 15),

                      // ADD TASK
                      GestureDetector(
                        onTap: _postTask,

                        child: const Text(
                          '+',

                          style: TextStyle(
                            fontSize: 40,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // IMAGE PREVIEW
                  if (_selectedImage != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),

                          child: Image.file(
                            _selectedImage!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),

                        Positioned(
                          top: 10,
                          right: 10,

                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImage = null;
                              });
                            },

                            child: Container(
                              padding: const EdgeInsets.all(6),

                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),

                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 30),

                  Text(
                    'task list',

                    style: _gaeguStyle.copyWith(color: Colors.redAccent),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _tasks.length,

                      itemBuilder: (context, index) {
                        final task = _tasks[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),

                          child: ListTile(
                            onTap: () {
                              _showEditDialog(
                                task['taskId'].toString(),

                                task['taskName'].toString(),

                                task['status'].toString(),

                                task['imageUrl'],
                              );
                            },

                            leading: const Icon(
                              Icons.task_alt,
                              color: Colors.green,
                            ),

                            title: Text(
                              task['taskName'] ?? "No Title",

                              style: _gaeguStyle.copyWith(fontSize: 18),
                            ),

                            subtitle: Text(task['status'] ?? "pending"),

                            trailing:
                                task['imageUrl'] != null &&
                                    task['imageUrl'].toString().isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),

                                    child: Image.network(
                                      task['imageUrl'],

                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,

                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const Icon(Icons.image);
                                          },
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
