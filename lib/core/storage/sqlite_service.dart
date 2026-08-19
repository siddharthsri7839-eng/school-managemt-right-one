import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SqliteService {
  static final SqliteService instance = SqliteService._internal();
  factory SqliteService() => instance;
  SqliteService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    // Enable FFI for desktop operating systems (Windows, macOS, Linux)
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'school_erp_demo.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Create Students Table
    await db.execute('''
      CREATE TABLE demo_students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        roll_number TEXT NOT NULL,
        class_name TEXT NOT NULL,
        section TEXT NOT NULL,
        parent_phone TEXT,
        gender TEXT
      )
    ''');

    // 2. Create Staff Table
    await db.execute('''
      CREATE TABLE demo_staff (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        department TEXT NOT NULL,
        email TEXT,
        phone TEXT
      )
    ''');

    // 3. Create Notices Table
    await db.execute('''
      CREATE TABLE demo_notices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL,
        author TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 4. Create Attendance Logs Table
    await db.execute('''
      CREATE TABLE demo_attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_name TEXT NOT NULL,
        class_section TEXT NOT NULL,
        status TEXT NOT NULL,
        date_time TEXT NOT NULL
      )
    ''');

    // Seed Demo Data
    await _seedDemoData(db);
  }

  Future<void> _seedDemoData(Database db) async {
    // Seed Demo Students
    await db.insert('demo_students', {
      'name': 'Aarav Sharma',
      'roll_number': '101',
      'class_name': 'Class 10',
      'section': 'A',
      'parent_phone': '+91 98765 43210',
      'gender': 'Male'
    });
    await db.insert('demo_students', {
      'name': 'Ananya Patel',
      'roll_number': '102',
      'class_name': 'Class 10',
      'section': 'A',
      'parent_phone': '+91 98765 43211',
      'gender': 'Female'
    });
    await db.insert('demo_students', {
      'name': 'Rohan Gupta',
      'roll_number': '103',
      'class_name': 'Class 10',
      'section': 'B',
      'parent_phone': '+91 98765 43212',
      'gender': 'Male'
    });
    await db.insert('demo_students', {
      'name': 'Priya Nair',
      'roll_number': '104',
      'class_name': 'Class 9',
      'section': 'A',
      'parent_phone': '+91 98765 43213',
      'gender': 'Female'
    });

    // Seed Demo Staff
    await db.insert('demo_staff', {
      'name': 'Dr. Rajesh Verma',
      'role': 'School Admin',
      'department': 'Administration',
      'email': 'admin@schoolerp.org',
      'phone': '+91 91234 56789'
    });
    await db.insert('demo_staff', {
      'name': 'Sunita Rao',
      'role': 'Senior Teacher',
      'department': 'Mathematics',
      'email': 'sunita.rao@schoolerp.org',
      'phone': '+91 91234 56790'
    });
    await db.insert('demo_staff', {
      'name': 'Vikram Singh',
      'role': 'Accountant',
      'department': 'Finance',
      'email': 'finance@schoolerp.org',
      'phone': '+91 91234 56791'
    });

    // Seed Demo Notices
    final now = DateTime.now().toString().split('.')[0];
    await db.insert('demo_notices', {
      'title': 'Annual Sports Day Announcement',
      'content': 'The Annual Sports Day will be held on 25th of next month. All students must register with physical education staff.',
      'category': 'Event',
      'author': 'Principal Office',
      'created_at': now
    });
    await db.insert('demo_notices', {
      'title': 'Mid-Term Examination Schedule',
      'content': 'Mid-term examinations will commence next Monday. Detailed timetable is posted on the notice board.',
      'category': 'Academic',
      'author': 'Examination Cell',
      'created_at': now
    });
    await db.insert('demo_notices', {
      'title': 'Parent-Teacher Meeting (PTM)',
      'content': 'Interactive PTM is scheduled for Saturday 10:00 AM to discuss student quarterly progress.',
      'category': 'Notice',
      'author': 'Academic Coordinator',
      'created_at': now
    });

    // Seed Demo Attendance
    await db.insert('demo_attendance', {
      'student_name': 'Aarav Sharma',
      'class_section': '10-A',
      'status': 'Present',
      'date_time': now
    });
    await db.insert('demo_attendance', {
      'student_name': 'Ananya Patel',
      'class_section': '10-A',
      'status': 'Present',
      'date_time': now
    });
    await db.insert('demo_attendance', {
      'student_name': 'Rohan Gupta',
      'class_section': '10-B',
      'status': 'Absent',
      'date_time': now
    });
  }

  // --- CRUD OPERATIONS ---

  // 1. Students
  Future<List<Map<String, dynamic>>> getStudents() async {
    final db = await database;
    return await db.query('demo_students', orderBy: 'id DESC');
  }

  Future<int> addStudent(Map<String, dynamic> student) async {
    final db = await database;
    return await db.insert('demo_students', student);
  }

  Future<int> deleteStudent(int id) async {
    final db = await database;
    return await db.delete('demo_students', where: 'id = ?', whereArgs: [id]);
  }

  // 2. Staff
  Future<List<Map<String, dynamic>>> getStaff() async {
    final db = await database;
    return await db.query('demo_staff', orderBy: 'id DESC');
  }

  // 3. Notices
  Future<List<Map<String, dynamic>>> getNotices() async {
    final db = await database;
    return await db.query('demo_notices', orderBy: 'id DESC');
  }

  Future<int> addNotice(Map<String, dynamic> notice) async {
    final db = await database;
    return await db.insert('demo_notices', notice);
  }

  Future<int> deleteNotice(int id) async {
    final db = await database;
    return await db.delete('demo_notices', where: 'id = ?', whereArgs: [id]);
  }

  // 4. Attendance
  Future<List<Map<String, dynamic>>> getAttendanceLogs() async {
    final db = await database;
    return await db.query('demo_attendance', orderBy: 'id DESC');
  }

  Future<int> addAttendanceLog(Map<String, dynamic> log) async {
    final db = await database;
    return await db.insert('demo_attendance', log);
  }

  // Database Metadata & Diagnostics
  Future<Map<String, dynamic>> getDatabaseSummary() async {
    final db = await database;
    final dbPath = await getDatabasesPath();
    final fullPath = join(dbPath, 'school_erp_demo.db');

    final studentCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM demo_students'),
    ) ?? 0;

    final staffCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM demo_staff'),
    ) ?? 0;

    final noticeCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM demo_notices'),
    ) ?? 0;

    final attendanceCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM demo_attendance'),
    ) ?? 0;

    return {
      'db_name': 'school_erp_demo.db',
      'db_path': fullPath,
      'db_version': await db.getVersion(),
      'is_open': db.isOpen,
      'student_count': studentCount,
      'staff_count': staffCount,
      'notice_count': noticeCount,
      'attendance_count': attendanceCount,
      'total_records': studentCount + staffCount + noticeCount + attendanceCount,
    };
  }

  // Reset & Reseed Database
  Future<void> resetAndSeedDatabase() async {
    final db = await database;
    await db.execute('DROP TABLE IF EXISTS demo_students');
    await db.execute('DROP TABLE IF EXISTS demo_staff');
    await db.execute('DROP TABLE IF EXISTS demo_notices');
    await db.execute('DROP TABLE IF EXISTS demo_attendance');
    await _onCreate(db, 1);
  }
}
