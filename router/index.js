// Bootstrap Node Logic (seedsphere-router)
import { createLibp2p } from 'libp2p';
import { tcp } from '@libp2p/tcp';
import { mplex } from '@libp2p/mplex';
import { noise } from '@chainsafe/libp2p-noise';
import { kadDHT } from '@libp2p/kad-dht';

const main = async () => {
    const node = await createLibp2p({
        addresses: {
            listen: ['/ip4/0.0.0.0/tcp/4001']
        },
        transports: [tcp()],
        streamMuxers: [mplex()],
        connectionEncryption: [noise()],
        services: {
            dht: kadDHT()
        }
    });

    await node.start();
    console.log('SeedSphere Bootstrap Node Active');
    console.log('PeerID:', node.peerId.toString());
    console.log('Listening on:', node.getMultiaddrs().map(m => m.toString()));
};

main();
