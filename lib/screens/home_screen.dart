// lib/screens/home_screen.dart

import 'package:flutter/material.dart';

import 'package:lsm_game/screens/game_screen.dart' as game_1;
import 'package:lsm_game/screens/game_screen_2.dart' as game_2;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LSM Game'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 50.0),
              child: Text(
                '¡Aprende LSM Jugando!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),

            // Botón para iniciar el juego 1
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                textStyle: const TextStyle(fontSize: 22),
              ),
              child: const Text('Iniciar Juego 1'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const game_1.GameScreen()));
              },
            ),

            const SizedBox(height: 30.0),
            // Botón para iniciar el juego 2
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                textStyle: const TextStyle(fontSize: 22),
              ),
              child: const Text('Iniciar Juego 2'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const game_2.GameScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
