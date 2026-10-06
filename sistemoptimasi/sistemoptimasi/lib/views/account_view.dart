import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'login_view.dart';

class AccountView extends StatelessWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Akun Oranger Antaran"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(

          children: [

            const CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xff6B7280),
              child: Icon(
                Icons.person,
                size: 40,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              "Oranger Antaran",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            // Card(
            //   child: ListTile(
            //     leading: const Icon(Icons.settings),
            //     title: const Text("Pengaturan"),
            //     onTap: () {},
            //   ),
            // ),

            Card(
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Logout"),

                onTap: () async {

                  await context.read<AuthViewModel>().logout();

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoginView(),
                    ),
                    (route) => false,
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
