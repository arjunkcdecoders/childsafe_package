import 'package:flutter/material.dart';
import 'package:childsafe_package/childsafe_package.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biometrics Tracker Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ExampleScreen(),
    );
  }
}

class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  late final BiometricsController controller;

  @override
  void initState() {
    super.initState();
    controller = BiometricsController();
    controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keystroke & Swipe Tracker')),
      body: Listener(
        onPointerDown: controller.handlePointerDown,
        onPointerMove: controller.handlePointerMove,
        onPointerUp: controller.handlePointerUp,
        onPointerCancel: controller.handlePointerCancel,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: controller.textController,
                onChanged: controller.onTextChanged,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Type and swipe here to test...',
                ),
              ),
              const SizedBox(height: 20),
              if (controller.isLoading)
                const CircularProgressIndicator()
              else
                Expanded(
                  child: ListView(
                    children: [
                      Text(
                        'Speed (IKI Mean): ${controller.ikiMean.toStringAsFixed(2)} ms',
                      ),
                      Text(
                        'Typo Rate: ${controller.typosPer100.toStringAsFixed(2)}%',
                      ),
                      const Divider(),
                      Text(
                        'Swipes Found: ${controller.completedSwipes.length}',
                      ),
                      Text(
                        'Swipe Avg Speed: ${controller.swipeSpeedMean.toStringAsFixed(2)} px/s',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => controller.clearData(),
        child: const Icon(Icons.clear),
      ),
    );
  }
}
