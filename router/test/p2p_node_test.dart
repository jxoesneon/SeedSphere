import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:router/p2p_node.dart';
import 'package:dart_ipfs/dart_ipfs.dart';

@GenerateNiceMocks([MockSpec<IPFSNode>()])
import 'p2p_node_test.mocks.dart';

void main() {
  group('P2PNode', () {
    late P2PNode p2pNode;
    late MockIPFSNode mockNode;

    setUp(() {
      mockNode = MockIPFSNode();
      p2pNode = P2PNode(nodeFactory: (config) async => mockNode);
    });

    test('start initializes and starts IPFS node', () async {
      when(mockNode.start()).thenAnswer((_) async {});
      when(mockNode.peerId).thenReturn('QmPeerId123');
      when(mockNode.addresses).thenReturn(['/ip4/127.0.0.1/tcp/4001']);

      await p2pNode.start();

      verify(mockNode.start()).called(1);
      expect(p2pNode.peerId, equals('QmPeerId123'));
      expect(p2pNode.addresses, contains('/ip4/127.0.0.1/tcp/4001'));
    });

    test('start called twice does not restart', () async {
      when(mockNode.start()).thenAnswer((_) async {});

      await p2pNode.start();
      await p2pNode.start();

      verify(mockNode.start()).called(1);
    });

    test('stop stops the node', () async {
      when(mockNode.start()).thenAnswer((_) async {});
      when(mockNode.stop()).thenAnswer((_) async {});

      await p2pNode.start();
      await p2pNode.stop();

      verify(mockNode.stop()).called(1);
    });

    test('getters return null/empty before start', () {
      expect(p2pNode.peerId, isNull);
      expect(p2pNode.addresses, isEmpty);
    });
  });
}
