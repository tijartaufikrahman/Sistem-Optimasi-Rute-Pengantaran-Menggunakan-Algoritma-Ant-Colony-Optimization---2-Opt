
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:sisopt/viewmodels/auth_viewmodel.dart';

import 'package:sisopt/views/optimasirute/list_optimasi.dart';
import 'package:sisopt/views/paketsaya/list_penugasan_view.dart';

import '../../config/api_config.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {

  late String baseUrl;

  int total = 0;
  int belum = 0;
  int proses = 0;
  int selesai = 0;

  
  @override
  void initState() {
    super.initState();
    init();    
  }

  Future<void> init() async {

    baseUrl = await ApiConfig.getApiUrl();

    final auth = Provider.of<AuthViewModel>(context, listen: false);

    await auth.loadUserFromStorage();

    await fetchDashboard();
  }

  Future<void> fetchDashboard() async {
    try {

      final auth = Provider.of<AuthViewModel>(context, listen: false);
      final user = auth.user;

      print("#77 USER GLOBAL: $user");
      print("#77 USER ID: ${user?.id}");

      if (user == null) {
        print("#77 USER MASIH NULL");
        return;
      }

      // 1. Coba hitung dari DRS aktif Oranger
      try {
        final drsRes = await http.get(Uri.parse("$baseUrl/api/drs?orangerId=${user.id}"));
        if (drsRes.statusCode == 200) {
          final List list = jsonDecode(drsRes.body);
          int tKiriman = 0;
          int completedDrs = 0;
          for (var item in list) {
            tKiriman += (item['totalKiriman'] as num? ?? 0).toInt();
            if (item['statusDRS'] == 'Completed') {
              completedDrs++;
            }
          }
          setState(() {
            total = tKiriman;
            selesai = completedDrs;
          });
          return;
        }
      } catch (e) {
        print("Fetch DRS stats error: $e");
      }

      // 2. Fallback ke endpoint lama jika ada
      final response = await http.get(
        Uri.parse("${baseUrl}/api/manajemen-antaran/dashboard/${user.id}"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          total = data['total'] ?? 0;
          belum = data['belum'] ?? 0;
          proses = data['proses'] ?? 0;
          selesai = data['selesai'] ?? 0;
        });
      }
    } catch (e) {
      print("ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthViewModel>(context);


    return Scaffold(
      backgroundColor: const Color(0xfffafafa),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// ================= HEADER =================
            Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),

              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xff004B8D),
        Color(0xff0F4C81),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),

              child: Row(
                children: [

                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      color: Color(0xff004B8D),
                    ),
                  ),

                  const SizedBox(width: 14),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text(
                        "Halo ${auth.user?.name ?? 'Guest'}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),

                      const Text(
                        "Selamat Bekerja",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                    ],
                  ),

                  const Spacer(),
                ],
              ),
            ),

            const SizedBox(height: 25),

            /// ================= TITLE =================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Tugas Pengantaran Hari Ini",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 15),

            /// ================= STAT GRID =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),

              child: GridView.count(
                padding: EdgeInsets.zero,
                crossAxisCount: 2,
                shrinkWrap: true,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.8,

                children: [

                  _StatCard(
                    title: "Total Kiriman",
                    value: total.toString(),
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xff004B8D),
                  ),

                  // _StatCard(
                  //   title: "Belum Dikirim",
                  //   value: belum.toString(),
                  //   icon: Icons.schedule_outlined,
                  //   color: const Color(0xffEE7D11),
                  // ),

                  // _StatCard(
                  //   title: "Dalam Proses",
                  //   value: proses.toString(),
                  //   icon: Icons.local_shipping_outlined,
                  //   color: const Color(0xff1565A9),
                  // ),

                  _StatCard(
                    title: "Selesai",
                    value: selesai.toString(),
                    icon: Icons.check_circle_outline,
                    color: const Color(0xff004B8D),
                  ),

                ],
              ),
            ),

            const SizedBox(height: 18),

            /// ================= MENU =================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Menu",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [

                  SizedBox(
                    width: 80,
                    child: _MenuItem(
                      icon: Icons.inventory,
                      title: "Penugasan",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ListPenugasanView(),
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(
                    width: 80,
                    child: _MenuItem(
                      icon: Icons.map,
                      title: "Optimasi Rute",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ListOptimasi(),
                          ),
                        );
                      },
                    ),
                  ),

                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

/// ================= STAT CARD =================
class _StatCard extends StatelessWidget {

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),

        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0,6),
            color: Color(0x12000000),
          )
        ],
      ),

      child: Row(
        children: [

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),

            ],
          )

        ],
      ),
    );
  }
}

/// ================= MENU ITEM =================
class _MenuItem extends StatelessWidget {

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: onTap,

      child: Column(
        children: [

          Container(
            width: 64,
            height: 64,

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),

              boxShadow: const [
                BoxShadow(
                  blurRadius: 18,
                  offset: Offset(0,6),
                  color: Color(0x12000000),
                )
              ],
            ),

            child: Icon(
              icon,
              size: 28,
              color: const Color.fromARGB(255, 28, 105, 171),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          )

        ],
      ),
    );
  }
}
