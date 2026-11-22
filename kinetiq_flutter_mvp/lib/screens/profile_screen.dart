import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as image;
import '../brand.dart';
import '../services/motion_data_service.dart';
import '../services/exports.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.service});
  final MotionDataService service;
  static const fields = {
    'name': 'Full name',
    'age': 'Age (years)',
    'gender': 'Gender',
    'height': 'Height (cm)',
    'weight': 'Weight (kg)',
    'email': 'Email',
    'device': 'Wearable name',
  };
  Future<void> edit(BuildContext context) async {
    final form = GlobalKey<FormState>(),
        values = Map<String, dynamic>.from(service.profile);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final f in fields.entries)
                    TextFormField(
                      initialValue: values[f.key]?.toString(),
                      maxLength: 100,
                      decoration: InputDecoration(
                        labelText: f.value,
                        counterText: '',
                      ),
                      keyboardType: ['age', 'height', 'weight'].contains(f.key)
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : f.key == 'email'
                          ? TextInputType.emailAddress
                          : TextInputType.text,
                      onSaved: (v) => values[f.key] = v?.trim(),
                      validator: (input) {
                        final v = input?.trim() ?? '';
                        if (v.isEmpty) return null;
                        if (f.key == 'email' &&
                            !RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(v)) {
                          return 'Enter a valid email address';
                        }
                        if (['height', 'age', 'weight'].contains(f.key)) {
                          final n = double.tryParse(v);
                          if (n == null ||
                              !n.isFinite ||
                              n <= 0 ||
                              n >
                                  (f.key == 'age'
                                      ? 125
                                      : f.key == 'height'
                                      ? 300
                                      : 700) ||
                              (f.key == 'age' && int.tryParse(v) == null)) {
                            return 'Enter a valid ${f.value.toLowerCase()}';
                          }
                        }
                        return null;
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                form.currentState!.save();
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true && context.mounted) {
      await perform(
        context,
        () => service.save({
          ...service.profile,
          for (final k in fields.keys) k: values[k],
        }),
      );
    }
  }

  Future<void> selectPhoto(BuildContext context) => perform(context, () async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (file == null) return;
    if (await file.length() > 8 * 1024 * 1024) {
      throw const FormatException('Photo is too large');
    }
    final decoder = image.findDecoderForData(await file.readAsBytes());
    final bytes = await file.readAsBytes();
    final size = decoder?.startDecode(bytes);
    if (size == null || size.width * size.height > 12000000) {
      throw const FormatException('Invalid photo');
    }
    final decoded = decoder!.decodeFrame(0);
    if (decoded == null) throw const FormatException('Invalid photo');
    final oriented = image.bakeOrientation(decoded);
    final thumb = oriented.width >= oriented.height
        ? image.copyResize(oriented, width: 192)
        : image.copyResize(oriented, height: 192);
    await service.save({
      ...service.profile,
      'photo': base64Encode(image.encodeJpg(thumb, quality: 82)),
    });
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      final s = service, p = s.profile;
      String value(String k, String fallback) =>
          ((p[k] as String?) ?? '').trim().isEmpty ? fallback : p[k];
      void save(String k, Object v) =>
          perform(context, () => s.save({...p, k: v}));
      return DashboardPage(
        children: [
          const Eyebrow('Personal workspace'),
          const Text('Your profile', style: headingStyle),
          gap,
          SplitPanel(
            left: CardBody('Personal details', [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.ice,
                    foregroundImage: p['photo'] is String
                        ? MemoryImage(base64Decode(p['photo'] as String))
                        : null,
                    child: Text(
                      value('name', 'K').characters.first.toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      value('name', 'Local profile'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: () => edit(context),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              gap,
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => selectPhoto(context),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Choose photo'),
                  ),
                  if (p['photo'] is String)
                    TextButton(
                      onPressed: () => perform(
                        context,
                        () => service.save({...service.profile, 'photo': null}),
                      ),
                      child: const Text('Remove photo'),
                    ),
                ],
              ),
              for (final k in ['email', 'age', 'gender', 'height', 'weight'])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fields[k]!,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                      Flexible(
                        child: Text(value(k, '—'), textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                ),
            ]),
            right: CardBody('Wearable device', [
              Eyebrow(s.active && !s.demo ? 'Connected' : 'Disconnected'),
              gap,
              Text(
                value('device', 'Wearable'),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(value('deviceId', 'Device ID unavailable')),
              gap,
              const Text(
                'Select Connect wearable on Home to discover a KINETIQ band.',
              ),
            ]),
          ),
          gap,
          SplitPanel(
            left: CardBody('Monitoring preferences', [
              const Text('Sustained high-motion alert'),
              DropdownButton<int>(
                isExpanded: true,
                value: s.threshold,
                items: [
                  for (final n in [0, 5, 15, 30, 60])
                    DropdownMenuItem(
                      value: n,
                      child: Text(
                        n == 0 ? 'Disabled' : 'After $n continuous seconds',
                      ),
                    ),
                ],
                onChanged: (n) {
                  if (n != null) save('threshold', n);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('In-app alert notifications'),
                value: p['notify'] != false,
                onChanged: (v) => save('notify', v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Save monitoring history'),
                subtitle: const Text('Store new readings on this device'),
                value: s.retain,
                onChanged: (v) => save('retain', v),
              ),
            ]),
            right: CardBody('Local data', [
              const Text(
                'Your profile and movement history are encrypted on this device. Exported files contain readable data.',
              ),
              gap,
              Builder(
                builder: (ctx) => OutlinedButton.icon(
                  onPressed: s.history.isEmpty
                      ? null
                      : () => perform(ctx, () {
                          final b = ctx.findRenderObject() as RenderBox;
                          return exportHistory(
                            s.history,
                            b.localToGlobal(Offset.zero) & b.size,
                          );
                        }),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Export motion history'),
                ),
              ),
              TextButton(
                onPressed: () => perform(context, () async {
                  final yes = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear monitoring history?'),
                      content: const Text(
                        'This ends the current session and permanently removes all demo and wearable recordings from this device.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Clear history'),
                        ),
                      ],
                    ),
                  );
                  if (yes == true) await s.clear();
                }),
                child: const Text('Clear monitoring history'),
              ),
            ]),
          ),
          gap,
          const CardBody('About $productName', [
            Text('Wearable motion monitoring · Version 0.2.0'),
            SizedBox(height: 8),
            SelectableText(
              'Prosthesis Leg by thunk3d.scanner (Sketchfab), licensed under CC BY 4.0. Adapted with a knee hinge, flexion animation and alert ring.\nhttps://sketchfab.com/3d-models/prosthesis-leg-6339595921fe491fb58772ec1502c87b\nhttps://creativecommons.org/licenses/by/4.0/',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ]),
        ],
      );
    },
  );
}
