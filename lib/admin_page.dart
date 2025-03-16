import 'package:appnoithat/task_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'change_password.dart';
import 'main.dart';
import 'manager_task_page.dart';
import 'manager_user_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  late Future<List<Map<String, String>>> _projects;
  late TextEditingController _searchController = TextEditingController();
  late List<Map<String, String>> _filteredProjects = [];

  // Lấy danh sách dự án từ Firebase
  Future<List<Map<String, String>>> _fetchProjects() async {
    final snapshot = await _database.child('projects').get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> projectsData = snapshot.value as Map< dynamic, dynamic>;
      return projectsData.values.map((project) {
        return {
          'id' : project['id'] as String,
          'name': project['name'] as String,
          'manager': project['manager'] as String,
        };
      }).toList();
    }
    return [];
  }


  @override
  void initState() {
    super.initState();
    _projects = _fetchProjects();
    _searchController = TextEditingController();
    _projects.then((data) {
      setState(() {
        _filteredProjects = data;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[800],
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          'Quản lý dự án',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      drawer: Drawer(
        width: 280,
        child: Container(
          color: Colors.grey[600],
          child: Column(
            children: [
              Container(
                height: 140, // Chiều cao
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/icon/logo.png', // Đường dẫn hình ảnh trong thư mục assets
                          height: 80, // Điều chỉnh kích thước hình ảnh
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildDrawerItem(
                icon: Icons.work_outline, // Chọn biểu tượng cho công việc
                title: 'Quản lý công việc',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToTaskManagement(); // Thêm hàm để điều hướng tới trang quản lý công việc
                },
              ),
              SizedBox(height: 16),
              _buildDrawerItem(
                icon: Icons.group,
                title: 'Quản lý nhân viên',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToEmployeeManagement();
                },
              ),
              _buildDrawerItem(
                icon: Icons.lock_outline,
                title: 'Đổi mật khẩu',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToChangePassword();
                },
              ),
              Spacer(),
              Divider(color:Colors.grey[800]),
              _buildDrawerItem(
                icon: Icons.exit_to_app,
                title: 'Đăng xuất',
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
                isLogout: true,
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
      body: Container(
        color: Colors.grey[100],
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm dự án...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  print("Giá trị nhập vào: $value");
                  _projects.then((data) {
                    print("Dữ liệu dự án: $data");
                    setState(() {
                      _filteredProjects = data.where((project) {
                        return project['name']!.toLowerCase().contains(value.toLowerCase());
                      }).toList();
                      print("Dữ liệu dự án: $_filteredProjects");
                    });
                  });
                },

              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, String>>>(
                future: _projects,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            'Đã xảy ra lỗi',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text('Không có dự án nào.'),
                    );
                  }

                  // Lưu dữ liệu đã tải vào _filteredProjects
                  if (_filteredProjects.isEmpty) {
                    _filteredProjects = snapshot.data!;
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(12),
                    itemCount: _filteredProjects.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),

                          title: Text(
                            _filteredProjects[index]['name']!,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),

                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                          onTap: () => _navigateToTasksPage(
                            _filteredProjects[index]['id']!,
                            _filteredProjects[index]['name']!,
                            _filteredProjects[index]['manager']!,
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProjectDialog,
        backgroundColor: Colors.grey[600],
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Thêm dự án',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _navigateToTaskManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaskManagementPage()), // Thay 'TaskManagementPage' bằng trang quản lý công việc của bạn
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isLogout ? Colors.red[300] : Colors.white,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isLogout ? Colors.red[300] : Colors.white,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      minLeadingWidth: 20,
      contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    );
  }
  void _navigateToTasksPage(String projectId,String projectName, String projectManager) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TasksPage(
          projectId: projectId, // Truyền ID vào
          projectName: projectName,
          projectManager: projectManager,
        ),
      ),
    );
  }

  // Hàm để đăng xuất
  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('role');  // Xóa trạng thái đăng nhập

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MyApp()),
    );
  }
  void _navigateToChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChangePasswordPage()), // Điều hướng đến trang đổi mật khẩu
    );
  }

  // Điều hướng đến trang quản lý nhân viên
  void _navigateToEmployeeManagement() {
    // Điều hướng đến trang quản lý nhân viên
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmployeeManagementPage()), // Thay thế bằng trang thực tế
    );
  }

  void _addNewProject(String name, String manager) async {
    final newProjectRef = _database.child('projects').push();
    final projectId = newProjectRef.key; // Lấy id của dự án mới

    await newProjectRef.set({
      'name': name,
      'manager': manager,
      'id': projectId,
    });

    // **Gọi lại _fetchProjects() để cập nhật danh sách**
    setState(() {
      _projects = _fetchProjects();
      _projects.then((data) {
        setState(() {
          _filteredProjects = data;
        });
      });
    });
  }


  // Hiển thị hộp thoại nhập tên dự án và tên người phụ trách
  void _showAddProjectDialog() {
    final _nameController = TextEditingController();
    final _managerController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // Đặt màu nền của AlertDialog là màu trắng
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, // Đặt borderRadius = 0 để các góc vuông
          ),
          title: const Text('Thêm dự án mới'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên dự án'),
              ),
              TextField(
                controller: _managerController,
                decoration: const InputDecoration(labelText: 'Tên người phụ trách'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Đóng hộp thoại
              },
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                final name = _nameController.text;
                final manager = _managerController.text;
                if (name.isNotEmpty && manager.isNotEmpty) {
                  _addNewProject(name, manager); // Thêm dự án mới vào Firebase
                  Navigator.of(context).pop(); // Đóng hộp thoại sau khi thêm
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );
  }

}
