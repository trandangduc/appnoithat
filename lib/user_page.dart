import 'package:appnoithat/task_page_user.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'change_password.dart';
import 'main.dart';

class UserPage extends StatefulWidget {
  const UserPage({Key? key}) : super(key: key);

  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  late Future<List<Map<String, String>>> _projects;
  late TextEditingController _searchController = TextEditingController();
  late List<Map<String, String>> _filteredProjects = [];
  // Lấy danh sách dự án từ Firebase
  Future<List<Map<String, String>>> _fetchProjects() async {
    final snapshot = await _database.child('projects').get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> projectsData = snapshot.value as Map<dynamic, dynamic>;
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
                icon: Icons.lock_outline,
                title: 'Đổi mật khẩu',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToChangePassword();
                },
              ),
              Spacer(),
              Divider(color: Colors.grey[800]),
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
              // Search TextField
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
                    _projects.then((data) {
                      setState(() {
                        _filteredProjects = data.where((project) {
                          return project['name']!
                              .toLowerCase()
                              .contains(value.toLowerCase());
                        }).toList();
                      });
                    });
                  },
                ),
              ),
              // Projects List
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text(
                              'Chưa có dự án nào',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Initialize filtered projects if empty
                    if (_filteredProjects.isEmpty) {
                      _filteredProjects = snapshot.data!;
                    }

                    // Display filtered projects
                    return ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _filteredProjects.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TasksPageUser(
                                      projectId: _filteredProjects[index]['id']!,
                                      projectName: _filteredProjects[index]['name']!,
                                      projectManager: _filteredProjects[index]['manager']!,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _filteredProjects[index]['name']!,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[900],
                                                  letterSpacing: 0.5,
                                                ),
                                              ),

                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          color: Colors.grey[400],
                                          size: 16,
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
                ),
              ),
            ],
          ),
        ),

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
        color: isLogout ? Colors.white : Colors.white,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isLogout ? Colors.white : Colors.white,
        ),
      ),
      onTap: onTap,
    );
  }
  Widget _buildProjectCard(BuildContext context, Map<String, String> project) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TasksPageUser(
              projectId: project['id']!,
              projectName: project['name']!,
              projectManager: project['manager']!,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.business, color: Colors.black),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      project['name']!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Người phụ trách: ${project['manager']}',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _navigateToChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChangePasswordPage()), // Điều hướng đến trang đổi mật khẩu
    );
  }
  // Hàm để đăng xuất
  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('role');  // Xóa trạng thái đăng nhập

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MyApp()), // Điều hướng về trang đăng nhập
    );
  }
}
