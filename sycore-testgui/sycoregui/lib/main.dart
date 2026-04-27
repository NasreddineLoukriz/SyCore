import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

// --- العمليات (GraphQL Operations) ---
final Map<String, String> apiOperations = {
  'Token Auth': '''mutation TokenAuth(\$username: String!, \$password: String!) {
    tokenAuth(username: \$username, password: \$password) { payload, refreshExpiresIn, token }
  }''',
  'Sign Up': '''mutation Signup(\$username: String!, \$email: String!, \$password: String!) {
    signup(username: \$username, email: \$email, password: \$password) {
      user { id, username, email, isUploadBanned, maxTotalAssets }
    }
  }''',
  'Create Resource': '''mutation CreateResource(\$data: String!, \$domain: String!, \$resourceType: String!) {
    createResource(data: \$data, domain: \$domain, resourceType: \$resourceType) {
      resource { id, data, domain, resourceType, createdAt }
    }
  }''',
  'Get User Resources': '''query GetUserResources(\$domain: String!, \$resourceType: String!) {
    userResources(domain: \$domain, resourceType: \$resourceType, limit: 10, offset: 0) {
      id, data, domain, resourceType, createdAt
    }
  }''',
  'Get All Users': '''query GetAllUsers {
    allUsers(limit: 10, offset: 0) {
      id, username, email, isActive, isUploadBanned, maxTotalAssets
    }
  }''',
  'Verify Token': '''mutation VerifyToken(\$token: String!) {
    verifyToken(token: \$token) { payload }
  }''',
  'Delete Resource': '''mutation DeleteResource(\$id: ID!) {
    deleteResource(id: \$id) { success }
  }''',
  'Get User Assets': '''query GetUserAssets(\$domain: String!) {
    userAssets(domain: \$domain, limit: 10, offset: 0) { id, domain, fileUrl, size, mimetype }
  }''',
};

// --- تعريف المتغيرات المطلوبة لكل عملية لتوليد الحقول ديناميكياً ---
final Map<String, List<String>> operationFields = {
  'Token Auth': ['username', 'password'],
  'Sign Up': ['username', 'email', 'password'],
  'Create Resource': ['data', 'domain', 'resourceType'],
  'Get User Resources': ['domain', 'resourceType'],
  'Get All Users': [],
  'Verify Token': ['token'],
  'Delete Resource': ['id'],
  'Get User Assets': ['domain'],
};

String? globalAuthToken;

void main() async {
  await initHiveForFlutter();
  runApp(const SycoreTestApp());
}

class SycoreTestApp extends StatelessWidget {
  const SycoreTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    final HttpLink httpLink = HttpLink('http://127.0.0.1:8000/graphql/');
    
    final AuthLink authLink = AuthLink(
      getToken: () async => globalAuthToken != null ? 'JWT $globalAuthToken' : null,
    );

    ValueNotifier<GraphQLClient> client = ValueNotifier(
      GraphQLClient(
        link: authLink.concat(httpLink),
        cache: GraphQLCache(store: HiveStore()),
      ),
    );

    return GraphQLProvider(
      client: client,
      child: MaterialApp(
        title: 'SYCORE API Tester',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.light,
          fontFamily: 'Tajawal',
        ),
        home: const ApiTesterDashboard(),
      ),
    );
  }
}

class ApiTesterDashboard extends StatefulWidget {
  const ApiTesterDashboard({super.key});

  @override
  State<ApiTesterDashboard> createState() => _ApiTesterDashboardState();
}

class _ApiTesterDashboardState extends State<ApiTesterDashboard> {
  String _consoleOutput = "=> منصة اختبار SYCORE-2139 جاهزة...\n";
  String _selectedOperationName = 'Token Auth';
  bool _isLoading = false;

  // تخزين المتحكمات (Controllers) للحقول الديناميكية
  Map<String, TextEditingController> _dynamicControllers = {};

  @override
  void initState() {
    super.initState();
    _buildControllersForOperation(_selectedOperationName);
    
    // قيم افتراضية للتسهيل
    if (_dynamicControllers.containsKey('username')) {
      _dynamicControllers['username']!.text = '0663103303';
    }
    if (_dynamicControllers.containsKey('password')) {
      _dynamicControllers['password']!.text = 'nasreddine';
    }
  }

  // بناء حقول النص استناداً للعملية المختارة
  void _buildControllersForOperation(String operationName) {
    // التخلص من المتحكمات القديمة
    _dynamicControllers.forEach((key, controller) => controller.dispose());
    _dynamicControllers.clear();

    final fields = operationFields[operationName] ?? [];
    for (String field in fields) {
      _dynamicControllers[field] = TextEditingController();
      
      // تعبئة بعض القيم الافتراضية
      if (field == 'domain') _dynamicControllers[field]!.text = 'testDomain';
      if (field == 'resourceType') _dynamicControllers[field]!.text = 'POST';
      if (field == 'data') _dynamicControllers[field]!.text = '{"message": "Hello SYCORE"}';
    }
  }

  void _updateConsole(String text) {
    setState(() {
      final timeArgs = DateTime.now().toString().split('.')[0];
      _consoleOutput = "[$timeArgs] $text\n\n-----------------\n$_consoleOutput";
    });
  }

  Future<void> _executeOperation() async {
    setState(() => _isLoading = true);
    _updateConsole("🚀 جاري تنفيذ: $_selectedOperationName...");
    
    // تجميع المتغيرات من الحقول
    Map<String, dynamic> variables = {};
    _dynamicControllers.forEach((key, controller) {
      variables[key] = controller.text;
    });

    final client = GraphQLProvider.of(context).value;
    final String queryDoc = apiOperations[_selectedOperationName]!;
    final bool isMutation = queryDoc.trim().startsWith('mutation');

    QueryResult result;
    if (isMutation) {
      result = await client.mutate(MutationOptions(
        document: gql(queryDoc),
        variables: variables,
        fetchPolicy: FetchPolicy.networkOnly,
      ));
    } else {
      result = await client.query(QueryOptions(
        document: gql(queryDoc),
        variables: variables,
        fetchPolicy: FetchPolicy.networkOnly,
      ));
    }

    if (result.hasException) {
      _updateConsole("❌ فشل:\n${result.exception.toString()}");
    } else {
      final dataStr = const JsonEncoder.withIndent('  ').convert(result.data);
      _updateConsole("✅ استجابة ناجحة:\n$dataStr");

      if (result.data != null && result.data!['tokenAuth'] != null) {
        setState(() {
          globalAuthToken = result.data!['tokenAuth']['token'];
        });
        _updateConsole("🔒 تم استلام التوكن وإرفاقه للطلبات القادمة بنجاح!");
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _dynamicControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = globalAuthToken != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('أداة اختبار SYCORE-2139', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        elevation: 2,
        shadowColor: Colors.black26,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Chip(
              avatar: Icon(
                isConnected ? Icons.check_circle : Icons.error_outline,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                isConnected ? "متصل (تم تسجيل الدخول)" : "غير مسجل الدخول",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: isConnected ? Colors.green.shade600 : Colors.red.shade400,
              side: BorderSide.none,
            ),
          )
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      body: Row(
        children: [
          // ======== اللوحة اليسرى (الإعدادات والتنفيذ) ========
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // بطاقة اختيار العملية
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.api, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              const Text("اختيار العملية (Operation)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            isExpanded: true,
                            value: _selectedOperationName,
                            items: apiOperations.keys.map((String key) {
                              return DropdownMenuItem<String>(
                                value: key, 
                                child: Text(key, style: const TextStyle(fontWeight: FontWeight.w600)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedOperationName = val!;
                                _buildControllersForOperation(_selectedOperationName);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // بطاقة مدخلات المتغيرات (UI الديناميكي)
                  Expanded(
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.input, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                const Text("المدخلات المطلوبة", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _dynamicControllers.isEmpty 
                                ? const Center(child: Text("لا توجد متغيرات مطلوبة لهذه العملية.", style: TextStyle(color: Colors.grey)))
                                : ListView.separated(
                                    itemCount: _dynamicControllers.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      String key = _dynamicControllers.keys.elementAt(index);
                                      return TextField(
                                        controller: _dynamicControllers[key],
                                        decoration: InputDecoration(
                                          labelText: key,
                                          border: const OutlineInputBorder(),
                                          prefixIcon: const Icon(Icons.short_text),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // زر التنفيذ الأساسي
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _executeOperation,
                    icon: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.play_arrow_rounded),
                    label: const Text('إرسال الطلب (Send Request)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // ======== اللوحة اليمنى (شاشة المخرجات Console) ========
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 16.0, right: 16.0),
              child: Card(
                color: const Color(0xFF1E1E1E), 
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                     Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.terminal, color: Colors.greenAccent, size: 20),
                              SizedBox(width: 8),
                              Text("المخرجات (Console)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          IconButton(
                            tooltip: "مسح الشاشة",
                            icon: const Icon(Icons.delete_sweep, color: Colors.grey, size: 20), 
                            onPressed: () => setState(() => _consoleOutput = "=> تم مسح الشاشة.\n")
                          )
                        ],
                      ),
                    ),
                    
                    // نص المخرجات الفعلي
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _consoleOutput,
                            style: const TextStyle(
                              color: Color(0xFF69F0AE),
                              fontFamily: 'monospace', 
                              fontSize: 14,
                              height: 1.5,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
