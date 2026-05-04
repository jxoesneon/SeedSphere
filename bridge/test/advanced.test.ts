import { describe, it, expect, vi, beforeEach } from 'vitest';
import { getCache, setCache } from '../src/cache';
import { canonicalize } from '../src/crypto';
import { normalizeSxxEyy } from '../src/normalizer';

describe('Bridge Advanced Utilities', () => {
    describe('Cache Service', () => {
        const mockKV = {
            get: vi.fn(),
            put: vi.fn(),
        };

        beforeEach(() => {
            vi.clearAllMocks();
        });

        it('should return null if KV is missing', async () => {
            expect(await getCache(null, 'key')).toBeNull();
        });

        it('should return null if data is missing', async () => {
            mockKV.get.mockResolvedValue(null);
            expect(await getCache(mockKV, 'key')).toBeNull();
        });

        it('should return streams if not expired', async () => {
            const streams = [{ name: 'S1', title: 'T1' }];
            mockKV.get.mockResolvedValue({
                ts: Date.now(),
                ttl: 10000,
                streams,
            });
            expect(await getCache(mockKV, 'key')).toEqual(streams);
        });

        it('should return stale data if allowed', async () => {
            const streams = [{ name: 'S1', title: 'T1' }];
            mockKV.get.mockResolvedValue({
                ts: Date.now() - 20000,
                ttl: 10000,
                streams,
            });
            expect(await getCache(mockKV, 'key', true)).toEqual(streams);
        });

        it('should save data to KV', async () => {
            const streams = [{ name: 'S1', title: 'T1' }];
            await setCache(mockKV, 'key', streams, 5000);
            expect(mockKV.put).toHaveBeenCalled();
        });
    });

    describe('Crypto Utility', () => {
        it('should canonicalize objects deterministically', () => {
            const obj1 = { b: 2, a: 1 };
            const obj2 = { a: 1, b: 2 };
            expect(canonicalize(obj1)).toBe('{"a":1,"b":2}');
            expect(canonicalize(obj1)).toBe(canonicalize(obj2));
        });

        it('should handle nested objects', () => {
            const obj = { z: { b: 2, a: 1 }, y: 3 };
            expect(canonicalize(obj)).toBe('{"y":3,"z":{"a":1,"b":2}}');
        });

        it('should handle arrays', () => {
            const obj = { b: [3, 2, 1], a: 1 };
            expect(canonicalize(obj)).toBe('{"a":1,"b":[3,2,1]}');
        });
    });

    describe('Normalizer Extra', () => {
        it('should normalize episode formats', () => {
            expect(normalizeSxxEyy('Show 1x01')).toBe('Show S01E01');
            expect(normalizeSxxEyy('Show s2e5')).toBe('Show S02E05');
            expect(normalizeSxxEyy('Show Season 1 Episode 10')).toBe('Show S01E10');
        });
    });
});
