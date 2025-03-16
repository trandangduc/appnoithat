import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:printing/printing.dart';
import 'task_page.dart';
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
  GlobalKey<_TasksPageState> tasksPageKey = GlobalKey<_TasksPageState>();
  late Future<List<Map<String, String>>> _projectTasks;
  late Stream<List<Map<String, dynamic>>> _projectTasksWithChecklist;
  List<Map<String, dynamic>>? _tasksData;
  bool showImage = true;
  @override
  void initState() {
    super.initState();
    _projectTasksWithChecklist = _fetchProjectTasksWithChecklist();
    _projectTasksWithChecklist.listen((data) {
      setState(() {
        _tasksData = data;
      });
    });
  }
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

  Future<void> _updateTaskFinish(String checklistId, String imageUrl) async {
    final taskFinishRef = _database.child('task_finish');

    try {
      final snapshot = await taskFinishRef
          .orderByChild('id_checklist_project_task')
          .equalTo(checklistId)
          .get(); // Chờ dữ liệu từ Firebase

      if (snapshot.exists && snapshot.value is Map) {
        final Map<dynamic, dynamic> taskFinishData = snapshot.value as Map<dynamic, dynamic>;
        final String taskFinishKey = taskFinishData.keys.first;

        await taskFinishRef.child(taskFinishKey).update({
          'imagePath': imageUrl,
          'time': DateTime.now().toIso8601String(),
        });


        print("Cập nhật thành công vào task_finish.");
      } else {
        print("Không tìm thấy bản ghi với checklistId: $checklistId");
      }
    } catch (e) {
      print("Lỗi khi cập nhật vào task_finish: $e");
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
        .asyncMap((event) => event)
        .asBroadcastStream(); // Chuyển thành Broadcast Stream
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

  Future<void> _updateChecklistStatus(String checklistId,String idtask,String name, bool newValue) async {
    await _database.child('checklist_project_task/$checklistId').update({
      'status': newValue ? true : false,
    });
    if (newValue) {
      // Lấy đường dẫn hình ảnh từ Firebase hoặc từ nơi bạn lưu
      String? imagePath = ''; // Đường dẫn hình ảnh bạn muốn thêm vào, có thể là null
      await _addTaskFinishRecord(checklistId,idtask,name, imagePath);
    }

  }


  void _showImagePickerDialog(BuildContext context, String checklistId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0), // Góc bo nhẹ, có thể đặt là 0 nếu cần góc vuông hoàn toàn
          ),
          backgroundColor: Colors.white, // Đảm bảo nền màu trắng

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.black),
                title: const Text("Chụp ảnh"),
                onTap: () {
                  _pickImageAndUpload(ImageSource.camera, checklistId);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.black),
                title: const Text("Chọn từ thư viện"),
                onTap: () {
                  _pickImageAndUpload(ImageSource.gallery, checklistId);
                  Navigator.pop(context);
                },
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
        backgroundColor: Colors.grey[800],
        elevation: 0,
        title: Text(
          widget.projectName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            color: Colors.white,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'export_pdf') {
                _showExportOptions();
              } else if (value == 'show_text') {
                setState(() {
                  showImage = !showImage;
                });
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'export_pdf',
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf, color: Colors.black),
                  title: Text('Xuất PDF'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'show_text',
                child: ListTile(
                  leading: Icon(Icons.text_snippet, color: Colors.black),
                  title: Text(showImage ? 'Hiển thị dạng chữ' : 'Xem bản đầy đủ'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[600],
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _projectTasksWithChecklist,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Lỗi khi tải dữ liệu: ${snapshot.error}",
                  style: const TextStyle(color: Colors.black),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  "Không có công việc nào.",
                  style: TextStyle(color: Colors.black),
                ),
              );
            }
            final tasks = snapshot.data!;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: tasks.map((task) {
                  return Container(
                    width: 300,
                    margin: const EdgeInsets.only(right: 12.0),
                    child: Card(
                      elevation: 4,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.black, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey, width: 0.5),
                              ),
                            ),
                            child: Text(
                              task['taskName'] ?? 'Không có tên',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: (task['checklist'] as List?)?.length ?? 0,
                              itemBuilder: (context, index) {
                                final checklistItem = task['checklist'][index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 6.0),
                                  color: Colors.grey[50],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: Colors.grey[400]!),
                                  ),
                                  child: Column(
                                    children: [
                                      if (showImage && checklistItem['imagePath']?.isNotEmpty == true)
                                        GestureDetector(
                                          onTap: () => _showImageInDialog(
                                            checklistItem['imagePath'],
                                          ),
                                          child: CachedNetworkImage(
                                            key: ValueKey(checklistItem['imagePath']),
                                            imageUrl: checklistItem['imagePath'],
                                            imageBuilder: (context, imageProvider) => Container(
                                              height: 120,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                                image: DecorationImage(
                                                  image: imageProvider,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            placeholder: (context, url) => Container(
                                              height: 120,
                                              width: double.infinity,
                                              color: Colors.grey[300],
                                              child: const Center(
                                                child: CircularProgressIndicator(),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              height: 120,
                                              width: double.infinity,
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.error),
                                            ),
                                          ),
                                        ),
                                      ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
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
                                                newValue,
                                              ).then((_) {
                                                setState(() {
                                                  checklistItem['status'] = newValue ? 'true' : 'false';
                                                });
                                              }).catchError((error) {
                                                print("Error updating status: $error");
                                              });
                                            }
                                          },
                                        ),
                                        title: Text(
                                          checklistItem['Name'] ?? 'Không có tên',
                                          style: TextStyle(
                                            color: checklistItem['status'] == 'true' ? Colors.green : Colors.black,
                                          ),
                                        ),
                                        trailing: showImage
                                            ? IconButton(
                                          icon: const Icon(Icons.camera_alt, color: Colors.black),
                                          onPressed: () => _showImagePickerDialog(context, checklistItem['id']),
                                        )
                                            : null,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[700], // Nền đen
          title: Text(
            "Xuất PDF",
            style: TextStyle(color: Colors.white), // Chữ trắng
          ),
          content: Text(
            "Chọn phương thức xuất PDF",
            style: TextStyle(color: Colors.white70), // Chữ màu xám nhạt
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                generateProjectPDF(true); // Xuất tất cả công việc
              },
              child: Text(
                "Xuất tất cả công việc",
                style: TextStyle(color: Colors.white70), // Nút màu xanh
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _selectTasksForExport(); // Mở hộp thoại chọn công việc
              },
              child: Text(
                "Chọn công việc để xuất",
                style: TextStyle(color: Colors.white70), // Nút màu đỏ
              ),
            ),
          ],
        );
      },
    );
  }

  void _selectTasksForExport() async {
    List<dynamic> allTasks = await projectTasksWithChecklist();
    List<dynamic> selectedTasks = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white, // Đặt màu nền trắng
              title: Text(
                "Chọn công việc để xuất",
                style: TextStyle(color: Colors.black), // Văn bản màu đen để dễ đọc
              ),
              content: SingleChildScrollView(
                child: Column(
                  children: allTasks.map((task) {
                    return CheckboxListTile(
                      title: Text(
                        task['taskName'],
                        style: TextStyle(color: Colors.black), // Đảm bảo chữ có màu đen
                      ),
                      value: selectedTasks.contains(task),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            selectedTasks.add(task);
                          } else {
                            selectedTasks.remove(task);
                          }
                        });
                      },
                      activeColor: Colors.red, // Màu khi checkbox được chọn
                      checkColor: Colors.white, // Màu dấu tick
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text("Hủy", style: TextStyle(color: Colors.red)), // Nút hủy có màu đỏ
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    generateProjectPDF(false, selectedTasks);
                  },
                  child: Text("Xuất PDF", style: TextStyle(color: Colors.black)), // Nút xác nhận màu xanh
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickImageAndUpload(ImageSource source, String checklistId) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source, // 🛠️ Đã sửa lỗi tại đây
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        File file = File(pickedFile.path);
        var response = await _uploadImageToCloudinary(file);

        if (response != null && response['secure_url'] != null) {
          String imageUrl = response['secure_url'];

          // Update database with new image URL
          await _database.child('checklist_project_task/$checklistId').update({
            'imagePath': imageUrl,
          });

          await _updateTaskFinish(checklistId, imageUrl);

          // Cập nhật dữ liệu hiện tại trong StreamBuilder
          setState(() {
            if (_tasksData != null) {
              for (var task in _tasksData!) {
                for (var item in (task['checklist'] as List? ?? [])) {
                  if (item['id'] == checklistId) {
                    item['imagePath'] = imageUrl;
                    break;
                  }
                }
              }
            }
          });

          // Xóa cache ảnh cũ để cập nhật ảnh mới
          await CachedNetworkImage.evictFromCache(imageUrl);
        } else {
          _showErrorDialog("Lỗi khi upload hình ảnh");
        }
      } else {
        // Không có tệp nào được chọn
        Navigator.pop(context);
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog("Lỗi xảy ra trong quá trình upload: $e");
    }
  }
  Future<Map<String, dynamic>?> _uploadImageToCloudinary(File file) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/dhgmarvdn/image/upload');
    final uploadPreset = 'appnoithat';

    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Upload timed out');
        },
      );

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        return jsonDecode(responseData);
      } else {
        print("Lỗi khi upload: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Lỗi trong quá trình upload: $e");
      return null;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Lỗi'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('Đóng'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  Future<List<Map<String, dynamic>>> projectTasksWithChecklist() async {
    final tasksSnapshot = await _fetchProjectTasks();

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
  Future<bool> _requestStoragePermission() async {
    AndroidDeviceInfo build = await DeviceInfoPlugin().androidInfo;
    print(build.version.sdkInt);
    if (build.version.sdkInt >= 33) {
      var status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    } else if (build.version.sdkInt >= 30) {
      var status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    } else {
      var status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  Future<void> generateProjectPDF(bool exportAll, [List<dynamic>? selectedTasks]) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);

    // Load font
    final fontData = await rootBundle.load('assets/fonts/arial.ttf');
    final ttf = pw.Font.ttf(fontData);

    // Load logo
    final logoImage = pw.MemoryImage(
      (await rootBundle.load('assets/icon/logopdf.jpg')).buffer.asUint8List(),
    );

    // Lấy dữ liệu checklist (giả lập)
    final projectTasks = exportAll ? await projectTasksWithChecklist() : selectedTasks ?? [];

    // Tạo trang PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          List<pw.Widget> content = [];

          // Header
          content.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(logoImage, width: 60, height: 60),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Dự án: ${widget.projectName}',
                      style: pw.TextStyle(font: ttf, fontSize: 20, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Người phụ trách: ${widget.projectManager}',
                      style: pw.TextStyle(font: ttf, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          );

          content.add(pw.SizedBox(height: 20));

          // Title
          content.add(
            pw.Container(
              width: double.infinity,
              alignment: pw.Alignment.center,
              padding: pw.EdgeInsets.symmetric(vertical: 8),
              color: PdfColors.red,
              child: pw.Text(
                'CHECK LIST THI CÔNG DỰ ÁN ${widget.projectName}',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          );

          content.add(pw.SizedBox(height: 10));

          // Chia nhỏ danh sách công việc theo từng nhóm để tránh lỗi
          final int maxRowsPerPage = 10; // Giới hạn số dòng trên mỗi trang
          int totalTasks = projectTasks.length;
          int pages = (totalTasks / maxRowsPerPage).ceil();

          for (int i = 0; i < pages; i++) {
            int start = i * maxRowsPerPage;
            int end = start + maxRowsPerPage;
            if (end > totalTasks) end = totalTasks;

            List sublist = projectTasks.sublist(start, end);
            content.add(_buildChecklistTable(sublist, ttf));


          }

          return content;
        },
      ),
    );


    final pdfBytes = await pdf.save();
    final fileName = 'Nghiệm thu nội bộ công việc ${widget.projectName}.pdf';
    final directory = Directory('/storage/emulated/0/Download');
    final file = File('${directory.path}/$fileName');

    // Kiểm tra quyền trước khi lưu
    if (await _requestStoragePermission()) {
      try {
        await file.writeAsBytes(pdfBytes);
        _showMessage('PDF đã lưu tại: Download/$fileName');
        OpenFile.open(file.path);
      } catch (e) {
        _showMessage('Lưu PDF thất bại: ${e.toString()}');
      }
    } else {
      _showMessage('Không có quyền lưu file!');
    }
  }

// Hiển thị thông báo
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

// Hàm tạo widget cho mỗi task
  pw.Widget _buildChecklistTable(List projectTasks, pw.Font ttf) {
    // Chia danh sách công việc thành từng cặp để hiển thị theo 2 cột
    List<List> taskPairs = [];
    for (int i = 0; i < projectTasks.length; i += 2) {
      if (i + 1 < projectTasks.length) {
        taskPairs.add([projectTasks[i], projectTasks[i + 1]]);
      } else {
        taskPairs.add([projectTasks[i]]);
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black),
      columnWidths: {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(3),
      },
      children: [
        // Table header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.orange200),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text(
                'CHECK LIST',
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
                'NỘI DUNG',
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
                'CHECK LIST',
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
                'NỘI DUNG',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        ...taskPairs.map((pair) {
          return pw.TableRow(
            children: [
              // First task's title cell
              pw.Container(
                padding: pw.EdgeInsets.all(8),
                color: PdfColors.red,
                alignment: pw.Alignment.center,
                child: pw.Text(
                  pair[0]['taskName'] ?? 'Unnamed Task',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              // First task's checklist items
              pw.Container(
                padding: pw.EdgeInsets.all(4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    ...((pair[0]['checklist'] as List?) ?? []).map((item) {
                      final bool isCompleted = item['status'] == 'true';
                      return pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 12,
                            height: 12,
                            margin: pw.EdgeInsets.only(right: 4, top: 2),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey),
                              color: isCompleted ? PdfColors.green : PdfColors.white,
                            ),
                            child: isCompleted
                                ? pw.Center(
                              child: pw.Text(
                                'v',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 8,
                                ),
                              ),
                            )
                                : pw.Container(),
                          ),
                          pw.Container(
                            margin: pw.EdgeInsets.only(top: 5),
                            child: pw.Wrap(
                              children: [
                                pw.Text(
                                  item['Name'] ?? '',
                                  style: pw.TextStyle(
                                    font: ttf,
                                    fontSize: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
              // Second task's title cell (if exists)
              pair.length > 1
                  ? pw.Container(
                padding: pw.EdgeInsets.all(8),
                color: PdfColors.red,
                alignment: pw.Alignment.center,
                child: pw.Text(
                  pair[1]['taskName'] ?? 'Unnamed Task',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              )
                  : pw.Container(),
              // Second task's checklist items (if exists)
              pair.length > 1
                  ? pw.Container(
                padding: pw.EdgeInsets.all(4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    ...((pair[1]['checklist'] as List?) ?? []).map((item) {
                      final bool isCompleted = item['status'] == 'true';
                      return pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 12,
                            height: 12,
                            margin: pw.EdgeInsets.only(right: 4, top: 2),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey),
                              color: isCompleted ? PdfColors.green : PdfColors.white,
                            ),
                            child: isCompleted
                                ? pw.Center(
                              child: pw.Text(
                                'v',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 8,
                                ),
                              ),
                            )
                                : pw.Container(),
                          ),
                          pw.Container(
                            margin: pw.EdgeInsets.only(top: 5),
                            child: pw.Wrap(
                              children: [
                                pw.Text(
                                  item['Name'] ?? '',
                                  style: pw.TextStyle(
                                    font: ttf,
                                    fontSize: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        ],
                      );
                    }).toList(),
                  ],
                ),
              )
                  : pw.Container(),
            ],
          );
        }).toList(),
      ],
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
