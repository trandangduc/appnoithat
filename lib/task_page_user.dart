import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
class TasksPageUser extends StatefulWidget {
  final String projectId;
  final String projectName;
  final String projectManager;

  const TasksPageUser({
    Key? key,
    required this.projectId,
    required this.projectName,
    required this.projectManager,
  }) : super(key: key);

  @override
  _TasksPageState createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPageUser> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  late Stream<List<Map<String, dynamic>>> _projectTasksWithChecklist;

  @override
  void initState() {
    super.initState();
    _projectTasksWithChecklist = _fetchProjectTasksWithChecklist();
  }
  Future<void> _addTaskFinishRecord(
      String checklistId,String idtask,String name, String? imagePath) async {
    try {
      // Lấy thời gian hiện tại
      String timeStamp = DateTime.now().toIso8601String();

      // Truy vấn để tìm bản ghi có id_checklist_project_task bằng checklistId
      final taskFinishRef = _database.child('task_finish');
      final query = taskFinishRef.orderByChild('id_checklist_project_task').equalTo(checklistId).get();

      final snapshot = await query;

      if (snapshot.exists && snapshot.value != null) {
        // Nếu đã có bản ghi, cập nhật bản ghi
        final taskFinishKey = (snapshot.value as Map).keys.first; // Lấy key của bản ghi cần cập nhật
        await taskFinishRef.child(taskFinishKey).update({
          'id_checklist_project_task': checklistId,
          'imagePath': imagePath ?? '',

          'time': timeStamp,
        });

        print("Cập nhật bản ghi vào bảng task_finish!");
      } else {
        // Nếu chưa có bản ghi, thêm mới bản ghi
        await taskFinishRef.push().set({
          'taskName' :name,
          'id_checklist_project_task': checklistId,
          'imagePath': imagePath ?? '',
          'projectId' : idtask ,
          'time': timeStamp,
        });

        print("Đã thêm bản ghi vào bảng task_finish!");
      }
    } catch (e) {
      print("Lỗi khi thêm hoặc cập nhật bản ghi vào bảng task_finish: $e");
    }
  }



  Stream<List<Map<String, dynamic>>> _fetchProjectTasksWithChecklist() {
    return _database
        .child('task_project')
        .orderByChild('projectId')
        .equalTo(widget.projectId)
        .onValue
        .map((event) {
      List<Map<String, dynamic>> taskList = [];
      if (event.snapshot.exists) {
        Map<dynamic, dynamic> tasksData = event.snapshot.value as Map<dynamic, dynamic>;

        return Future.wait(tasksData.entries.map((entry) async {
          String taskId = entry.value['taskId'] as String;
          String taskName = entry.value['taskName'] as String;

          final checklistSnapshot = await _database
              .child('checklist_project_task')
              .orderByChild('id_task_project')
              .equalTo(taskId)
              .get();

          List<Map<String, String>> checklist = [];
          if (checklistSnapshot.exists) {
            Map<dynamic, dynamic> checklistData =
            checklistSnapshot.value as Map<dynamic, dynamic>;
            checklist = checklistData.entries.map((e) {
              return {
                'id_task_project': e.value['id_task_project'].toString(),
                'id': e.key.toString(),
                'Name': e.value['Name']?.toString() ?? '',
                'status': e.value['status']?.toString() ?? '',
                'imagePath': e.value['imagePath']?.toString() ?? '',
              };
            }).toList();
          }

          return {
            'taskId': taskId,
            'taskName': taskName,
            'checklist': checklist,
          };
        }));
      }
      return Future.value(taskList);
    })
        .asyncMap((event) => event);
  }
  Future<void> _updateChecklistStatus(String checklistId,String idtask,String name, bool newValue) async {
    await _database.child('checklist_project_task/$checklistId').update({
      'status': newValue ? true : false,
    });
    if (newValue) {
      // Lấy đường dẫn hình ảnh từ Firebase hoặc từ nơi bạn lưu
      String? imagePath = ''; // Đường dẫn hình ảnh bạn muốn thêm vào, có thể là null
      await _addTaskFinishRecord(checklistId,idtask,name, imagePath);
    }
    setState(() {
      _projectTasksWithChecklist = _fetchProjectTasksWithChecklist();
    });
  }
  Future<void> _updateTaskFinish(String checklistId, String imageUrl) async {
    final taskFinishRef = _database.child('task_finish');

    try {
      // Tìm bản ghi có id_checklist_project_task trùng với checklistId
      final query = taskFinishRef.orderByChild('id_checklist_project_task').equalTo(checklistId).get();

      final snapshot = await query;

      if (snapshot.exists && snapshot.value is Map) {
        // Nếu có bản ghi trùng, lấy key của bản ghi đó và cập nhật
        final taskFinishKey = (snapshot.value as Map).keys.first;
        await taskFinishRef.child(taskFinishKey).update({
          'imagePath': imageUrl, // Cập nhật đường dẫn hình ảnh
          'time': DateTime.now().toIso8601String(), // Cập nhật thời gian hiện tại
        });

        print("Cập nhật thành công vào task_finish.");
      } else {
        print("Không tìm thấy bản ghi với checklistId: $checklistId");
      }
    } catch (e) {
      print("Lỗi khi cập nhật vào task_finish: $e");
    }
  }

  Widget _buildTaskWithChecklistSection(String title, Stream<List<Map<String, dynamic>>> taskStream) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: taskStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          );
        } else if (snapshot.hasError) {
          return _buildErrorWidget("Lỗi khi tải dữ liệu: ${snapshot.error}");
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyStateWidget("Không có công việc nào.");
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: snapshot.data!.map((task) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ExpansionTile(
                title: Text(
                  task['taskName'],
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: (task['checklist'] as List<dynamic>).map<Widget>((checklistItem) {
                  return _buildChecklistItemTile(checklistItem);
                }).toList(),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildChecklistItemTile(dynamic checklistItem) {
    return ListTile(
      leading: Checkbox(
        activeColor: Colors.black,
        checkColor: Colors.white,
        value: checklistItem['status'] == 'true',
        onChanged: (bool? newValue) {
          if (newValue != null) {
            _updateChecklistStatus(
                checklistItem['id'],
                checklistItem['id_task_project'],
                checklistItem['Name'],
                newValue
            );
          }
        },
      ),
      title: Text(
        checklistItem['Name'],
        style: TextStyle(
          color: checklistItem['status'] == 'true'
              ? Colors.grey
              : Colors.black87,
          decoration: checklistItem['status'] == 'true'
              ? TextDecoration.lineThrough
              : null,
        ),
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.camera_alt,
          color: Colors.black,
        ),
        onPressed: () => _pickImageAndUpload(checklistItem['id']),
      ),
      subtitle: checklistItem['imagePath'] != ''
          ? GestureDetector(
        onTap: () => _showImageInDialog(checklistItem['imagePath']),
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              checklistItem['imagePath'],
              width: 250,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
        ),
      )
          : null,
    );
  }

  Future<void> _pickImageAndUpload(String checklistId) async {
    try {
      final picker = ImagePicker();
      print("Mở bộ chọn ảnh...");
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
      print("Ảnh đã chọn: ${pickedFile?.path}");

      if (pickedFile != null) {
        File file = File(pickedFile.path);

        // In thông tin tệp
        print("Tệp đã chọn: ${file.path}");

        // Thực hiện yêu cầu upload hình ảnh bằng API Cloudinary
        print("Bắt đầu upload lên Cloudinary...");
        var response = await _uploadImageToCloudinary(file);

        if (response != null && response['secure_url'] != null) {
          print("Hình ảnh đã upload thành công: ${response['secure_url']}");

          // Cập nhật đường dẫn hình ảnh vào Firebase
          await _database.child('checklist_project_task/$checklistId').update({
            'imagePath': response['secure_url'],
          });
          String imageUrl = response['secure_url'];
          await _updateTaskFinish(checklistId, imageUrl);
          setState(() {
            // Hiển thị đường dẫn hình ảnh đã upload lên Cloudinary
            print('Hình ảnh đã upload: ${response['secure_url']}');

              _projectTasksWithChecklist = _fetchProjectTasksWithChecklist();
          });
        } else {
          print("Lỗi khi upload hình ảnh, không có URL bảo mật.");
        }
      } else {
        print("Không có tệp nào được chọn.");
      }
    } catch (e) {
      print("Lỗi xảy ra trong quá trình upload: $e");
    }
  }

  Future<Map<String, dynamic>?> _uploadImageToCloudinary(File file) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/dhgmarvdn/image/upload');
    final uploadPreset = 'appnoithat';  // Thay đổi với Upload preset của bạn từ Cloudinary

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final Map<String, dynamic> data = jsonDecode(responseData);
      return data;
    } else {
      print("Lỗi khi upload: ${response.statusCode}");
      return null;
    }
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          widget.projectName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: Colors.grey[100],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTaskWithChecklistSection("📌 Công việc dự án", _projectTasksWithChecklist),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.grey,
            size: 60,
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checklist_outlined,
            color: Colors.grey,
            size: 60,
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
