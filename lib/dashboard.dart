import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<dynamic> _tasks = [];
  final TextEditingController _taskController = TextEditingController();
  bool _isLoading = true;

  final TextStyle _gaeguStyle = const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    fontFamily: 'Gaegu',
    color: Colors.black,
  );

  @override
  void initState() {
    super.initState();
    _fetchTasks(); // Load data from AWS on startup
  }

  // GET data from your AWS Invoke Link
  Future<void> _fetchTasks() async {
    final url = Uri.parse(
      'https://jbaodzbzwa.execute-api.us-east-1.amazonaws.com/prod/tasks/',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _tasks = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        debugPrint("Error fetching tasks: ${response.statusCode}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching tasks: $e");
      setState(() => _isLoading = false);
    }
  }

  // Function to POST a new task to AWS
  Future<void> _postTask() async {
    final String taskText = _taskController.text.trim();

    if (taskText.isEmpty) return;

    final url = Uri.parse(
      'https://jbaodzbzwa.execute-api.us-east-1.amazonaws.com/prod/tasks/',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'taskId': DateTime.now().millisecondsSinceEpoch
              .toString(), // Unique ID for the task
          'taskName':
              taskText, // Ensure this key matches your AWS Lambda/DynamoDB schema
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Clear text field and refresh list to show the new item from the server
        _taskController.clear();
        _fetchTasks();
      } else {
        debugPrint("Failed to add task: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error posting task: $e");
    }
  }

  Future<void> _showEditDialog(
    String id,
    String currentTitle,
    String status,
  ) async {
    final TextEditingController editController = TextEditingController(
      text: currentTitle,
    );

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Task', style: _gaeguStyle),
          content: TextField(
            controller: editController,
            style: _gaeguStyle.copyWith(fontSize: 18),
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.green),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _updateTask(id, editController.text, status);
                if (mounted) Navigator.pop(context);
              },
              child: const Text(
                'Update',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            // DELETE BUTTON
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.7),
              ),
              onPressed: () async {
                await _deleteTask(id);
                if (mounted) Navigator.pop(context);
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            /* const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),*/
          ],
        );
      },
    );
  }

  Future<void> _updateTask(String id, String newTitle, String status) async {
    // Check if your API expects /tasks/ID or just /tasks/
    final url = Uri.parse(
      'https://jbaodzbzwa.execute-api.us-east-1.amazonaws.com/prod/tasks/$id',
    );

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'taskId': id,
          'taskName': newTitle,
          'status': status,
        }), // Ensure this matches your AWS schema
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchTasks(); // Refresh list after update
      }
    } catch (e) {
      debugPrint("Error updating task: $e");
    }
  }

  Future<void> _deleteTask(String id) async {
    // Ensure the URL matches your AWS path for deletion
    final url = Uri.parse(
      'https://jbaodzbzwa.execute-api.us-east-1.amazonaws.com/prod/tasks/$id',
    );

    try {
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _fetchTasks(); // Refresh list after deleting
      } else {
        debugPrint("Delete failed with status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error deleting task: $e");
    }
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
                  const SizedBox(height: 60),

                  // Input field (UI only for now)
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
                      const SizedBox(width: 20),
                      // Wrap the '+' Text in a GestureDetector for tapping
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

                  const SizedBox(height: 40),
                  Text(
                    'task list',
                    style: _gaeguStyle.copyWith(color: Colors.redAccent),
                  ),

                  // Displaying the data from AWS
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    )
                  : ListView.builder(
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          horizontalTitleGap: 0,
                          onTap: () {
                            // Pass the ID and current Title from your data source
                            _showEditDialog(
                              _tasks[index]['taskId'].toString(),
                              _tasks[index]['taskName'].toString(),
                              _tasks[index]['status'].toString(),
                            );
                          },
                          leading: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15.0,
                            ),
                            child: const Icon(
                              Icons.check_box_outline_blank,
                              color: Colors.redAccent,
                            ),
                          ),
                          title: Text(
                            _tasks[index]['taskName'] ?? "No Title",
                            style: _gaeguStyle.copyWith(fontSize: 18),
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
