import 'package:flutter/material.dart';

import 'app.dart';
import 'services/server_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved servers from local storage
  final storageService = await ServerStorageService.create();
  final savedServers = await storageService.loadServers();

  runApp(VcrApp(
    storageService: storageService,
    initialSavedServers: savedServers,
  ));
}
