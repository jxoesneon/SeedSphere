import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:dart_ipfs/dart_ipfs.dart';

void main() async {
  final out = File('test_isolate_output.txt').openWrite();
  final receivePort = ReceivePort();

  try {
    out.writeln('Spawning IPFS isolate...');
    final isolate = await Isolate.spawn(_isolateEntry, receivePort.sendPort);

    final completer = Completer<void>();
    receivePort.listen((message) {
      out.writeln('Isolate Message: $message');
      if (message == 'DONE' || message.toString().contains('ERROR')) {
        completer.complete();
      }
    });

    await completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        out.writeln('Main thread timed out waiting for isolate.');
      },
    );

    isolate.kill();
    receivePort.close();
    out.writeln('Test complete.');
    await out.flush();
    await out.close();
    exit(0);
  } catch (e, st) {
    out.writeln('FATAL ERROR in main: $e');
    out.writeln(st);
    await out.close();
    exit(1);
  }
}

void _isolateEntry(SendPort sendPort) async {
  try {
    sendPort.send('Isolate started. Creating node...');
    final repoPath = '${Directory.current.path}/test_ipfs_isolate_repo';
    final repoDir = Directory(repoPath);
    if (repoDir.existsSync()) {
      repoDir.deleteSync(recursive: true);
    }
    repoDir.createSync(recursive: true);

    final node = await IPFSNode.create(
      IPFSConfig(
        dataPath: '$repoPath/data',
        datastorePath: '$repoPath/data',
        keystorePath: '$repoPath/keystore',
        offline: false,
        customConfig: const {
          'AutoNAT.Enabled': false,
          'AutoNAT.ServiceMode': 'client',
          'Discovery.MDNS.Enabled': true,
          'Pubsub.Router': 'gossipsub',
        },
        network: NetworkConfig(
          listenAddresses: const [
            '/ip4/0.0.0.0/tcp/0',
            '/ip4/0.0.0.0/udp/0/quic',
          ],
          bootstrapPeers: [],
          enableNatTraversal: false,
        ),
        enableLibp2pBridge: false,
      ),
    );

    sendPort.send('Node created. Starting with 45s timeout...');
    await node.start().timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        sendPort.send('ERROR: Startup timed out');
      },
    );

    sendPort.send('Node started successfully.');
    await node.stop();
    sendPort.send('DONE');
  } catch (e, st) {
    sendPort.send('ERROR: $e\n$st');
  }
}
