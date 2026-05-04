import { describe, it, expect, vi, beforeEach } from 'vitest';
import app from '../src/index';

describe('Bridge Application', () => {
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

    it('GET /manifest.json should return manifest', async () => {
        const res = await app.request('/manifest.json', {}, mockEnv);
        expect(res.status).toBe(200);
        const data = await res.json();
        expect(data.name).toBe('SeedSphere');
    });

    it('GET /stream/movie/tt123 should return streams', async () => {
        (global.fetch as any).mockResolvedValue({
            ok: true,
            json: async () => ({ results: [] }),
        });

        const res = await app.request('/stream/movie/tt123.json', {}, mockEnv);
        expect(res.status).toBe(200);
        const data = await res.json();
        expect(data).toHaveProperty('streams');
    });
});
