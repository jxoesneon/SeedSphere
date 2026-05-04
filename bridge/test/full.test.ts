import { describe, it, expect, vi, beforeEach } from 'vitest';
import app from '../src/index';

describe('Bridge Full Coverage', () => {
    const mockEnv = {
        KV_CACHE: {
            get: vi.fn().mockResolvedValue(null),
            put: vi.fn().mockResolvedValue(undefined),
        },
        ROUTER_URL: 'http://router',
    };

    beforeEach(() => {
        vi.clearAllMocks();
        global.fetch = vi.fn();
    });

    it('should handle tracker optimization', async () => {
        // Mock Torrentio response
        (global.fetch as any).mockResolvedValueOnce({
            ok: true,
            json: async () => ({
                streams: [{ url: 'magnet:?xt=urn:btih:abc&tr=udp://t1', title: 'S1' }]
            }),
        });

        // Mock Router query response
        (global.fetch as any).mockResolvedValueOnce({
            ok: true,
            json: async () => ({ results: [] }),
        });

        // Mock Tracker optimization response
        (global.fetch as any).mockResolvedValueOnce({
            ok: true,
            json: async () => ({ added: ['udp://t2'] }),
        });

        const res = await app.request('/stream/movie/tt123.json', {}, mockEnv);
        expect(res.status).toBe(200);
        const data = await res.json();
        expect(data.streams[0].url).toContain('udp%3A%2F%2Ft2');
    });

    it('should handle configuration strings', async () => {
        (global.fetch as any).mockResolvedValue({
            ok: true,
            json: async () => ({ streams: [] }),
        });

        const res = await app.request('/auto_proxy=off/stream/movie/tt123.json', {}, mockEnv);
        expect(res.status).toBe(200);
        // Verify fetch was NOT called for Torrentio (first fetch would be router query)
        expect(global.fetch).toHaveBeenCalledTimes(1); 
    });

    it('should handle subtitles with config', async () => {
        (global.fetch as any).mockResolvedValue({
            ok: true,
            json: async () => ({ data: [] }),
        });

        const res = await app.request('/test=1/subtitles/movie/tt123.json', {}, { ...mockEnv, OPENSUBTITLES_API_KEY: 'k' });
        expect(res.status).toBe(200);
    });

    it('should handle manifest with config', async () => {
        const res = await app.request('/test=1/manifest.json', {}, mockEnv);
        expect(res.status).toBe(200);
    });

    it('should handle failures gracefully in tracker optimization', async () => {
        (global.fetch as any).mockResolvedValueOnce({
            ok: true,
            json: async () => ({ streams: [{ url: 'magnet:?xt=urn:btih:abc', title: 'S1' }] }),
        });
        (global.fetch as any).mockResolvedValueOnce({
            ok: true,
            json: async () => ({ results: [] }),
        });
        // Tracker optimization fails
        (global.fetch as any).mockResolvedValueOnce({
            ok: false,
        });

        const res = await app.request('/stream/movie/tt123.json', {}, mockEnv);
        expect(res.status).toBe(200);
    });
});
