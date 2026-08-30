import 'package:flutter/material.dart';

class EncryptionStatus extends StatefulWidget {
  final bool isEncrypted;
  final bool triggerAnimation;

  const EncryptionStatus({
    Key? key,
    required this.isEncrypted,
    this.triggerAnimation = false,
  }) : super(key: key);

  @override
  State<EncryptionStatus> createState() => _EncryptionStatusState();
}

class _EncryptionStatusState extends State<EncryptionStatus> {
  double _scale = 1.0;

  @override
  void didUpdateWidget(EncryptionStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.triggerAnimation && !oldWidget.triggerAnimation) {
      _triggerBounce();
    }
  }

  void _triggerBounce() {
    setState(() => _scale = 1.3);
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) setState(() => _scale = 1.0);
    });
  }

  void _showSecurityInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(children: [SizedBox(width: 10), Text('Защищенный чат')]),
        content: Text(
          'Ваши сообщения защищены сквозным шифрованием. '
          'Ключи хранятся только на вашем устройстве и устройстве собеседника.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Понятно',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSecurityInfo(context),
      child: AnimatedScale(
        scale: _scale,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.isEncrypted ? Icons.lock : Icons.lock_open,
              color: Colors.green.shade700,
              size: 20.0,
            ),
          ],
        ),
      ),
    );
  }
}
