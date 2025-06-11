import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signin_screen.dart';
import 'signup_screen.dart';
import 'firebase_options.dart';
import 'calendar_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/signin': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const Homescreen(),
        '/calendar': (context) => const CalendarScreen(),
        '/local-calendar': (context) => LocalCalendarScreen(events: []), // Dummy, ganti events di navigasi
      },
    );
  }
}

class Task {
  String title;
  TimeOfDay? reminder;
  bool isDone;
  Task({required this.title, this.reminder, this.isDone = false});
}

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  List<Task> todolist = [];
  final TextEditingController _controller = TextEditingController();
  int updateIndex = -1;
  TimeOfDay? _reminderTime;
  DateTime? _selectedDate;

  final user = FirebaseAuth.instance.currentUser;
  final CollectionReference tasksCollection = FirebaseFirestore.instance.collection('tasks');

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  Future<void> fetchTasks() async {
    if (user == null) return;
    final snapshot = await tasksCollection.where('uid', isEqualTo: user!.uid).get();
    setState(() {
      todolist = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['date'] != null
          ? TaskWithDate(
              title: data['title'],
              reminder: data['reminder'] != null ? TimeOfDay(
                hour: data['reminder']['hour'],
                minute: data['reminder']['minute'],
              ) : null,
              isDone: data['isDone'] ?? false,
              date: (data['date'] as Timestamp).toDate(),
            )
          : Task(
              title: data['title'],
              reminder: data['reminder'] != null ? TimeOfDay(
                hour: data['reminder']['hour'],
                minute: data['reminder']['minute'],
              ) : null,
              isDone: data['isDone'] ?? false,
            );
      }).toList();
    });
  }

  Future<void> addList(String task) async {
    if (user == null) return;
    final newTask = TaskWithDate(title: task, reminder: _reminderTime, date: _selectedDate);
    setState(() {
      todolist.add(newTask);
      _controller.clear();
      _reminderTime = null;
      _selectedDate = null;
    });
    await tasksCollection.add({
      'uid': user!.uid,
      'title': newTask.title,
      'reminder': newTask.reminder != null ? {'hour': newTask.reminder!.hour, 'minute': newTask.reminder!.minute} : null,
      'isDone': newTask.isDone,
      'date': newTask.date != null ? Timestamp.fromDate(newTask.date!) : null,
    });
  }

  Future<void> updateListItem(String task, int index) async {
    if (user == null) return;
    final snapshot = await tasksCollection.where('uid', isEqualTo: user!.uid).get();
    final docId = snapshot.docs[index].id;
    setState(() {
      todolist[index].title = task;
      todolist[index].reminder = _reminderTime;
      if (todolist[index] is TaskWithDate) {
        (todolist[index] as TaskWithDate).date = _selectedDate;
      }
      _controller.clear();
      updateIndex = -1;
      _reminderTime = null;
      _selectedDate = null;
    });
    await tasksCollection.doc(docId).update({
      'title': task,
      'reminder': _reminderTime != null ? {'hour': _reminderTime!.hour, 'minute': _reminderTime!.minute} : null,
      'date': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
    });
  }

  Future<void> deleteItem(int index) async {
    if (user == null) return;
    final snapshot = await tasksCollection.where('uid', isEqualTo: user!.uid).get();
    final docId = snapshot.docs[index].id;
    setState(() {
      todolist.removeAt(index);
    });
    await tasksCollection.doc(docId).delete();
  }

  Future<void> toggleDone(int index) async {
    if (user == null) return;
    final snapshot = await tasksCollection.where('uid', isEqualTo: user!.uid).get();
    final docId = snapshot.docs[index].id;
    setState(() {
      todolist[index].isDone = !todolist[index].isDone;
    });
    await tasksCollection.doc(docId).update({
      'isDone': todolist[index].isDone,
    });
  }

  Future<void> pickReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  Future<void> pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void showTaskDialog({bool isEdit = false, int? index}) {
    if (isEdit && index != null) {
      _controller.text = todolist[index].title;
      _reminderTime = todolist[index].reminder;
      updateIndex = index;
      _selectedDate = todolist[index] is TaskWithDate ? (todolist[index] as TaskWithDate).date : null;
    } else {
      _controller.clear();
      _reminderTime = null;
      updateIndex = -1;
      _selectedDate = null;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Task' : 'Add New Task'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(labelText: 'Task'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Reminder:'),
                    const SizedBox(width: 10),
                    Text(_reminderTime != null ? _reminderTime!.format(context) : '-'),
                    IconButton(
                      icon: const Icon(Icons.alarm),
                      onPressed: pickReminderTime,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Tanggal:'),
                    const SizedBox(width: 10),
                    Text(_selectedDate != null ? '${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}' : '-'),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: pickDate,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _controller.clear();
              _reminderTime = null;
              _selectedDate = null;
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_controller.text.trim().isEmpty) return;
              if (isEdit && index != null) {
                updateListItem(_controller.text.trim(), index);
              } else {
                addList(_controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF3B3DBF),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Today', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('${todolist.length} tasks', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF3B3DBF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => showTaskDialog(),
                      child: const Text('Add New'),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Image.asset('assets/images/to-do.png', height: 32),
                      tooltip: 'Lihat Kalender',
                      onPressed: () {
                        Navigator.pushNamed(context, '/calendar');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: 'Logout',
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/signin');
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView.builder(
                padding: const EdgeInsets.all(32),
                itemCount: todolist.length,
                itemBuilder: (context, index) {
                  final task = todolist[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Material(
                      color: task.isDone ? const Color(0xFF3B3DBF) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 3,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => toggleDone(index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                          child: Row(
                            children: [
                              Checkbox(
                                value: task.isDone,
                                onChanged: (_) => toggleDone(index),
                                activeColor: const Color(0xFF3B3DBF),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: TextStyle(
                                        color: task.isDone ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    if (task.reminder != null)
                                      Text(
                                        'Reminder: ${task.reminder!.format(context)}',
                                        style: TextStyle(
                                          color: task.isDone ? Colors.white70 : Colors.grey[700],
                                          fontSize: 15,
                                        ),
                                      ),
                                    if (task is TaskWithDate && task.date != null)
                                      Text(
                                        'Tanggal: 	${task.date!.day}-${task.date!.month}-${task.date!.year}',
                                        style: TextStyle(
                                          color: task.isDone ? Colors.white70 : Colors.grey[700],
                                          fontSize: 15,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.orange),
                                tooltip: 'Edit',
                                onPressed: () => showTaskDialog(isEdit: true, index: index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete',
                                onPressed: () => deleteItem(index),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Tambahkan widget AuthWrapper di bawah ini
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const Homescreen();
        } else {
          return const SignInScreen();
        }
      },
    );
  }
}

// Tambahkan class turunan Task untuk menyimpan tanggal
class TaskWithDate extends Task {
  DateTime? date;
  TaskWithDate({required String title, TimeOfDay? reminder, bool isDone = false, this.date}) : super(title: title, reminder: reminder, isDone: isDone);
}