import { describe, it, expect, vi, beforeEach } from 'vitest';
import { fetchTorrentio, fetchOpenSubtitles } from '../src/providers';

describe('Bridge Providers', () => {
    const mockEnv = {
        OPENSUBTITLES_API_KEY: 'test-key',
    };

    beforeEach(() => {
        vi.clearAllMocks();
        global.fetch = vi.fn();
    });

    it('fetchTorrentio should handle successful response', async () => {
        const streams = [{ infoHash: 'abc', title: 'Stream 1' }];
        (global.fetch as any).mockResolvedValue({
            ok: true,
            status: 200,
            json: async () => ({ streams }),
        });

        const results = await fetchTorrentio('movie', 'tt123');
        expect(results).toHaveLength(1);
        expect(results[0].provider).toBe('Torrentio');
    });

    it('fetchTorrentio should handle error response', async () => {
        (global.fetch as any).mockResolvedValue({
            ok: false,
            status: 500,
            text: async () => 'Error',
        });

        const results = await fetchTorrentio('movie', 'tt123');
        expect(results).toHaveLength(0);
    });

    it('fetchOpenSubtitles should handle successful response', async () => {
        const data = [
            { id: '1', attributes: { files: [{ file_id: 'f1', url: 'http://sub' }], language: 'en' } }
        ];
        (global.fetch as any).mockResolvedValue({
            ok: true,
            json: async () => ({ data }),
        });

        const results = await fetchOpenSubtitles('movie', 'tt123', mockEnv);
        expect(results).toHaveLength(1);
        expect(results[0].lang).toBe('en');
    });

    it('fetchOpenSubtitles should handle missing API key', async () => {
        const results = await fetchOpenSubtitles('movie', 'tt123', {});
        expect(results).toHaveLength(0);
    });
});
