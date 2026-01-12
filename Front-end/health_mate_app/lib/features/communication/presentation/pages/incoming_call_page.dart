import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'call_page.dart';

/// Incoming Call Screen
/// Shown when receiving a call offer

class IncomingCallPage extends StatelessWidget {
  final String callerName;
  final String callerId;
  final bool isVideo;

  const IncomingCallPage({
    super.key,
    required this.callerName,
    required this.callerId,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isVideo ? 'Incoming Video Call...' : 'Incoming Audio Call...',
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline Button
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(24),
                          backgroundColor: Colors.red,
                        ),
                        child: const Icon(Icons.call_end, size: 32),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Decline',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),

                  // Accept Button
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close incoming screen
                          // Navigate to CallPage as Answerer
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CallPage(
                                isVideo: isVideo,
                                contactName: callerName,
                                contactId: callerId,
                                isCaller: false, // Important: answering
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(24),
                          backgroundColor: Colors.green,
                        ),
                        child: const Icon(Icons.call, size: 32),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Accept',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
