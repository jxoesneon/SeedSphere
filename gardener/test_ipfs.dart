import 'dart:io';
import 'package:dart_ipfs/dart_ipfs.dart';

void main() async {
  final out = File('test_output.txt').openWrite();
  try {
    out.writeln('Creating IPFSNode in test script...');
    final repoPath = '${Directory.current.path}/test_ipfs_repo';
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
    out.writeln('IPFSNode created. Starting...');
    await node.start().timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        out.writeln('FATAL ERROR: IPFS Node start timed out (45s)');
        throw Exception('IPFS Node failed to start within 45s');
      },
    );
    out.writeln('IPFSNode started successfully.');
    await out.flush();
    await node.stop();
    out.writeln('Done.');
    await out.close();
    exit(0);
  } catch (e, st) {
    out.writeln('FATAL ERROR: $e');
    out.writeln(st);
    await out.close();
    exit(1);
  }
}
