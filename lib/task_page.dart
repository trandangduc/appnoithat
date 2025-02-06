import 'dart:io';

import 'package:appnoithat/task_detail.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show Offset, rootBundle;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
class TasksPage extends StatefulWidget {
  final String projectId;
  final String projectName;
  final String projectManager;

  const TasksPage({
    Key? key,
    required this.projectId,
    required this.projectName,
    required this.projectManager,
  }) : super(key: key);

  @override
  _TasksPageState createState() => _TasksPageState();
}
class _TasksPageState extends State<TasksPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Danh sách các task đã hoàn thành
  late Future<List<Map<String, String>>> _finishedTasks;
  late Future<List<Map<String, String>>> _projectTasks;
  late Future<List<Map<String, String>>> _Tasks;

  // Lấy danh sách các task đã hoàn thành từ Firebase
  Future<List<Map<String, String>>> _fetchFinishedTasks() async {
    // Lấy danh sách các taskId từ bảng task_project
    final projectSnapshot = await _database
        .child('task_project')
        .orderByChild('projectId') // Lọc theo projectId
        .equalTo(widget.projectId) // Dự án có ID tương ứng
        .get();

    if (projectSnapshot.exists) {
      Map<dynamic, dynamic> projectData = projectSnapshot.value as Map<dynamic, dynamic>;

      // In ra giá trị của projectData
      print('Project Data: $projectData');

      // Lấy các taskId từ dữ liệu của task_project
      List<String> taskIds = projectData.entries.map((entry) {
        return entry.value['taskId'] as String;
      }).toList();

      // In ra giá trị của taskIds
      print('Task IDs: $taskIds');

      // Bây giờ lấy các task hoàn thành từ task_finish theo taskId
      List<Map<String, String>> finishedTasks = [];

      for (var taskId in taskIds) {
        final taskSnapshot = await _database
            .child('task_finish')
            .orderByChild('projectId') // Lọc theo id_checklist_project_task (taskId)
            .equalTo(taskId) // So sánh với taskId
            .get();

        if (taskSnapshot.exists) {
          Map<dynamic, dynamic> taskData = taskSnapshot.value as Map<dynamic, dynamic>;

          // In ra giá trị của taskData
          print('Task Data: $taskData');

          finishedTasks.addAll(taskData.entries.map((entry) {
            // In ra từng entry trong taskData
            print('Entry: $entry');

            return {
              'taskName': entry.value['taskName'] as String,
              'imagePath': entry.value['imagePath'] as String,
              'time': entry.value['time'] as String,
            };
          }).toList());
        }
      }

      // In ra kết quả cuối cùng
      print('Finished Tasks: $finishedTasks');
      return finishedTasks;
    }

    // Trả về danh sách rỗng nếu không có dữ liệu
    print('No finished tasks found.');
    return [];
  }


  // Lấy danh sách các task từ bảng task_project
  Future<List<Map<String, String>>> _fetchProjectTasks() async {
    final snapshot = await _database
        .child('task_project')
        .orderByChild('projectId') // Lọc theo projectId
        .equalTo(widget.projectId)
        .get();

    if (snapshot.exists) {
      Map<dynamic, dynamic> tasksData = snapshot.value as Map<dynamic, dynamic>;
      return tasksData.entries.map((entry) {
        return {
          'taskId' : entry.value['taskId'] as String,
          'taskName': entry.value['taskName'] as String,
        };
      }).toList();
    }
    return [];
  }

  // Lấy danh sách các task từ bảng tacvu
  Future<List<Map<String, String>>> _fetchTasks() async {
    final snapshot = await _database
        .child('tacvu')
        .orderByChild('id') // Lọc theo projectId
        .get();

    if (snapshot.exists) {
      Map<dynamic, dynamic> tasksData = snapshot.value as Map<dynamic, dynamic>;
      return tasksData.entries.map((entry) {
        return {
          'id': entry.value['id'] as String,
          'taskName': entry.value['tentacvu'] as String,
        };
      }).toList();
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    // Initialize the Futures to fetch data
    _finishedTasks = _fetchFinishedTasks(); // Lấy danh sách task đã hoàn thành
    _projectTasks = _fetchProjectTasks(); // Lấy danh sách task của dự án
    _Tasks = _fetchTasks(); // Lấy danh sách tác vụ từ bảng 'tacvu'
  }

  // Hàm để thêm một task mới vào Firebase
  Future<void> _addNewTask(String taskName) async {
    final newTaskRef = _database.child('task_project').push();
    final taskId = newTaskRef.key; // Lấy id của task mới
    newTaskRef.set({
      'taskId': taskId,
      'taskName': taskName,
      'projectId': widget.projectId,
    });
    // Lấy danh sách các tác vụ từ bảng tacvu
    List<Map<String, String>> taskList = await _fetchTasks();

    // Tìm id tác vụ tương ứng
    String id = '';
    for (var task in taskList) {
      if (task['taskName'] == taskName) {
        id = task['id']!;
        break;
      }
    }

    // Lấy tất cả dữ liệu trong bảng 'checklist'
    final snapshotChecklist = await _database.child('checklist').get();

    if (snapshotChecklist.exists) {
      final checklistData = snapshotChecklist.value as Map<dynamic, dynamic>;  // Ép kiểu đúng

      checklistData.forEach((key, value) async {
        // Kiểm tra nếu 'id' trong checklist trùng với id bạn muốn tìm
        if (value['id'] == id) {
          // Tạo một mục mới trong bảng 'checklist_project_task'
          final newChecklistRef = _database.child('checklist_project_task').push();
          newChecklistRef.set({
            'id': newChecklistRef.key,
            'id_task_project': taskId,
            'Name': value['ten'],  // Tên task bạn muốn thêm
            'id_checklist': value['id'],  // id trùng với id trong bảng checklist
            'status': false,  // Thêm trạng thái vào
            'imagePath': '',  // Thêm trường hình ảnh vào
          });
        }
      });
    }

    setState(() {
        _finishedTasks = _fetchFinishedTasks(); // Lấy danh sách task đã hoàn thành
        _projectTasks = _fetchProjectTasks(); // Lấy danh sách task của dự án
        _Tasks = _fetchTasks(); // Lấy danh sách tác vụ từ bảng 'tacvu'
      });
    }


  // Hàm mở dialog để thêm task mới
  void _showAddTaskDialog() {
    final taskNameController = TextEditingController();
    final Set<String> selectedTasks = {};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog.fullscreen(
              child: SafeArea(
                child: Scaffold(
                  backgroundColor: Colors.white,
                  body: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Thêm công việc mới',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.black54, size: 28),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        Divider(height: 32, color: Colors.grey[300]),

                        TextField(
                          controller: taskNameController,
                          decoration: InputDecoration(
                            labelText: 'Tên công việc mới',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Theme.of(context).primaryColor),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            prefixIcon: Icon(Icons.add_task, color: Colors.grey[600]),
                            contentPadding: EdgeInsets.all(16),
                          ),
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 24),

                        Text(
                          'Tác vụ hiện có:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 12),

                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: FutureBuilder<List<Map<String, String>>>(
                              future: _Tasks,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  );
                                } else if (snapshot.hasError) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red[400], size: 48),
                                        SizedBox(height: 12),
                                        Text(
                                          'Đã xảy ra lỗi',
                                          style: TextStyle(color: Colors.red[400], fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  );
                                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'Chưa có công việc nào.',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  padding: EdgeInsets.all(12),
                                  itemCount: snapshot.data!.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    color: Colors.grey[200],
                                  ),
                                  itemBuilder: (context, index) {
                                    final task = snapshot.data![index];
                                    return ListTile(
                                      leading: Checkbox(
                                        value: selectedTasks.contains(task['taskName']),
                                        onChanged: (bool? selected) {
                                          setState(() {
                                            if (selected != null && selected) {
                                              selectedTasks.add(task['taskName']!);
                                            } else {
                                              selectedTasks.remove(task['taskName']!);
                                            }
                                          });
                                        },
                                        activeColor: Theme.of(context).primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      title: Text(
                                        task['taskName']!,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      dense: true,
                                      tileColor: Colors.white,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'Hủy',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 16,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                backgroundColor: Colors.grey[100],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                if (taskNameController.text.isNotEmpty || selectedTasks.isNotEmpty) {
                                  if (taskNameController.text.isNotEmpty) {
                                    _addNewTask(taskNameController.text);
                                  }
                                  selectedTasks.forEach((taskName) {
                                    _addNewTask(taskName);
                                  });
                                  Navigator.of(context).pop();
                                }
                              },
                              child: Text(
                                'Thêm',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Theme.of(context).primaryColor,
                                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTask(String taskId) async {
    await _database.child('task_project').child(taskId).remove();
    setState(() {
      _finishedTasks = _fetchFinishedTasks(); // Lấy danh sách task đã hoàn thành
      _projectTasks = _fetchProjectTasks(); // Lấy danh sách task của dự án
      _Tasks = _fetchTasks(); // Lấy danh sách tác vụ từ bảng 'tacvu'
    });
  }

  void _showDeleteTaskConfirmation(String taskId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white, // Đặt nền màu trắng cho hộp thoại
          title: Text('Xác nhận xóa công việc', style: TextStyle(color: Colors.black)),
          content: Text(
            'Bạn có chắc chắn muốn xóa công việc này? Tất cả checklist sẽ bị xóa.',
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () {
                _deleteTask(taskId); // Xóa công việc dựa trên taskId
                Navigator.pop(context);
              },
              child: Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          widget.projectName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: generateProjectPDF,
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[100],
        child: Column(
          children: [
            // Active Tasks Section
            Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Checklist cần thực hiện',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    height: 280,
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _projectTasksWithChecklist(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                                SizedBox(height: 8),
                                Text(
                                  'Đã xảy ra lỗi',
                                  style: TextStyle(color: Colors.red[300]),
                                ),
                              ],
                            ),
                          );
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(

                            child: InkWell(
                              onTap: _showAddTaskDialog,
                              borderRadius: BorderRadius.circular(16),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Thêm công việc',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        final tasks = snapshot.data!;
                        return ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          scrollDirection: Axis.horizontal,
                          itemCount: tasks.length + 1,
                          itemBuilder: (context, index) {
                            if (index == tasks.length) {
                              return Container(
                                width: 280,
                                margin: EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: _showAddTaskDialog,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_circle_outline,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Thêm công việc',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            final task = tasks[index];
                            final completedItems = task['checklist']
                                .where((item) => item['status'] == 'true')
                                .length;
                            final totalItems = task['checklist'].length;
                            final progress = totalItems > 0 ? completedItems / totalItems : 0.0;

                            return Container(
                              width: 280,
                              margin: EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChecklistPage(taskId: task['taskId']),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  task['taskName'],
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                icon: Icon(Icons.more_vert, color: Colors.white70),
                                                color: Colors.white,
                                                elevation: 8,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                onSelected: (value) {
                                                  if (value == 'delete') {
                                                    _showDeleteTaskConfirmation(task['taskId']);
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.delete_outline, color: Colors.red),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Xóa',
                                                          style: TextStyle(color: Colors.red),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 16),
                                          Expanded(
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: task['checklist'].length,
                                              itemBuilder: (context, i) {
                                                final item = task['checklist'][i];
                                                return Padding(
                                                  padding: EdgeInsets.symmetric(vertical: 4),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        item['status'] == 'true'
                                                            ? Icons.check_circle
                                                            : Icons.radio_button_unchecked,
                                                        color: item['status'] == 'true'
                                                            ? Colors.green
                                                            : Colors.white60,
                                                        size: 20,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          item['Name'],
                                                          style: TextStyle(
                                                            color: Colors.white70,
                                                            fontSize: 14,
                                                            decoration: item['status'] == 'true'
                                                                ? TextDecoration.lineThrough
                                                                : null,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          SizedBox(height: 16),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Tiến độ',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${(progress * 100).toInt()}%',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: progress,
                                                  backgroundColor: Colors.white24,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                                  minHeight: 6,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
            ,

            // Completed Tasks Section
            Expanded(
              child: FutureBuilder<List<Map<String, String>>>(  // Lấy dữ liệu từ Future
                future: _finishedTasks,  // Hàm trả về dữ liệu
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[700]!),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: Colors.grey[800], size: 48),
                            SizedBox(height: 16),
                            Text(
                              'Đã xảy ra lỗi',
                              style: TextStyle(
                                color: Colors.grey[900],
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '${snapshot.error}',
                              style: TextStyle(color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.assignment_turned_in_outlined,
                              color: Colors.grey[400],
                              size: 64,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Chưa có công việc nào hoàn thành',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Lấy danh sách các công việc từ dữ liệu
                  final tasks = snapshot.data!;

                  // Sắp xếp danh sách tasks theo thời gian từ mới nhất đến lâu nhất
                  tasks.sort((a, b) {
                    final timeA = DateTime.parse(a['time'] ?? ''); // Chuyển chuỗi thời gian thành DateTime
                    final timeB = DateTime.parse(b['time'] ?? '');
                    return timeB.compareTo(timeA);  // So sánh ngược để mới nhất ở đầu
                  });

                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (tasks[index]['imagePath'] != null &&
                                    (tasks[index]['imagePath'] as String?)?.isNotEmpty == true) {
                                  _showImageInDialog(tasks[index]['imagePath']!);
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (tasks[index]['imagePath'] != null &&
                                      (tasks[index]['imagePath'] as String?)?.isNotEmpty == true)
                                    Stack(
                                      children: [
                                        Container(
                                          height: 200,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            image: DecorationImage(
                                              image: NetworkImage(tasks[index]['imagePath']!),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 80,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.black.withOpacity(0.4),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 16,
                                          right: 16,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.6),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.check_circle_outline,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Hoàn thành',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  Container(
                                    padding: EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                tasks[index]['taskName'] ?? 'Không có tên công việc',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[900],
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              margin: EdgeInsets.only(left: 16),
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                Icons.arrow_forward_ios,
                                                color: Colors.grey[600],
                                                size: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 16),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 18,
                                                color: Colors.grey[700],
                                              ),
                                              SizedBox(width: 12),
                                              Text(
                                                _formatDate(tasks[index]['time']) ?? 'Chưa có ngày hoàn thành',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            )

          ],
        ),
      ),

    );
  }
  void _showImageInDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Semi-transparent background
              Container(
                color: Colors.black.withOpacity(0.8),
              ),

              // Centered image with pinch-to-zoom
              Center(
                child: PhotoViewGallery.builder(
                  itemCount: 1,
                  builder: (context, index) {
                    return PhotoViewGalleryPageOptions(
                      imageProvider: NetworkImage(imageUrl),
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 3,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  Icons.error_outline,
                                  color: Colors.white,
                                  size: 50
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Không thể tải hình ảnh',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    );
                  },
                  scrollPhysics: const BouncingScrollPhysics(),
                  pageController: PageController(),
                ),
              ),

              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(8),
                    child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
// Hàm để định dạng lại thời gian
  String? _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;

    try {
      // Giả sử dateStr là dạng 'yyyy-MM-dd HH:mm:ss'
      DateTime dateTime = DateTime.parse(dateStr); // Chuyển đổi từ chuỗi thành DateTime
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime); // Định dạng ngày tháng năm
    } catch (e) {
      return 'Không thể định dạng ngày';
    }
  }
// Hàm mới để lấy task kèm checklist
  Future<List<Map<String, dynamic>>> _projectTasksWithChecklist() async {
    final tasksSnapshot = await _projectTasks;

    List<Map<String, dynamic>> taskList = [];

    for (var entry in tasksSnapshot) {
      String? taskId = entry['taskId'];
      String? taskName = entry['taskName'];

      // Lấy checklist cho từng task
      final checklistSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('checklist_project_task')
          .orderByChild('id_task_project')
          .equalTo(taskId)
          .get();

      List<Map<String, dynamic>> checklist = [];
      if (checklistSnapshot.exists) {
        final checklistData = checklistSnapshot.value as Map<dynamic, dynamic>;
        checklist = checklistData.entries.map((e) {
          return {
            'id': e.key.toString(),
            'Name': e.value['Name']?.toString() ?? '',
            'status': e.value['status']?.toString() ?? '',
            'imagePath': e.value['imagePath']?.toString() ?? '', // Đảm bảo có imagePath
          };
        }).toList();
      }

      taskList.add({
        'taskId': taskId,
        'taskName': taskName,
        'checklist': checklist, // Đảm bảo là List<Map<String, dynamic>>
      });
    }
    return taskList;
  }
  Future generateProjectPDF() async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);
    final fontData = await rootBundle.load('assets/fonts/arial.ttf');
    final ttf = pw.Font.ttf(fontData);

    final projectTasks = await _projectTasksWithChecklist();

    final List tasksWithImages = await Future.wait(
      projectTasks.map((task) async {
        final List checklistWithImages = await Future.wait(
          (task['checklist'] as List).map((item) async {
            final checklistItem = item as Map;
            if (checklistItem['imagePath'] != null && checklistItem['imagePath'].isNotEmpty) {
              final imageBytes = await _getImageBytes(checklistItem['imagePath']);
              return {...checklistItem, 'imageBytes': imageBytes};
            }
            return checklistItem;
          }).toList(),
        );
        return {...task, 'checklist': checklistWithImages};
      }).toList(),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Dự án: ${widget.projectName}',
              style: pw.TextStyle(font: ttf, fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Paragraph(
            text: 'Người phụ trách: ${widget.projectManager}',
            style: pw.TextStyle(font: ttf, fontSize: 14),
          ),
          ...tasksWithImages.map((task) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
                borderRadius: pw.BorderRadius.circular(8),
                boxShadow: [
                  pw.BoxShadow(
                    color: PdfColors.grey300,
                    blurRadius: 5,
                  ),
                ],
              ),
              margin: pw.EdgeInsets.only(bottom: 16),
              padding: pw.EdgeInsets.all(16),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    task['taskName'] ?? 'Unnamed Task',
                    style: pw.TextStyle(font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey),
                    columnWidths: {
                      0: pw.FlexColumnWidth(3),
                      1: pw.FlexColumnWidth(1),
                      2: pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.blue100),
                        children: [
                          pw.Padding(
                            padding: pw.EdgeInsets.all(8),
                            child: pw.Text('Tên công việc', style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(8),
                            child: pw.Text('Trạng thái', style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(8),
                            child: pw.Text('Hình', style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      ...task['checklist'].map<pw.TableRow>((checklistItem) {
                        final bool isCompleted = checklistItem['status'] == 'true';
                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(
                                checklistItem['Name'],
                                style: pw.TextStyle(
                                  font: ttf,
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(
                                isCompleted ? '✔' : '✘',
                                style: pw.TextStyle(
                                  font: ttf,
                                  fontSize: 12,
                                  color: isCompleted ? PdfColors.green : PdfColors.red,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: checklistItem.containsKey('imageBytes')
                                  ? pw.Image(
                                pw.MemoryImage(checklistItem['imageBytes']),
                                width: 50,
                                height: 50,
                                fit: pw.BoxFit.cover,
                              )
                                  : pw.Container(),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );

    final pdfBytes = await pdf.save();
    final directory = await getExternalStorageDirectory();
    final fileName = 'Project_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory!.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    print("PDF đã lưu tại: ${file.path}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF đã lưu tại ${file.path}'), duration: Duration(seconds: 3)),
    );
  }



// Helper method to fetch image bytes
  Future<Uint8List> _getImageBytes(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      return response.bodyBytes;
    } catch (e) {
      print('Error loading image: $e');
      return Uint8List(0);
    }
  }
}


