import { describe, it, expect } from 'vitest';
import { toTitleNatural, parseReleaseInfo } from '../src/index';

describe('Bridge Utilities', () => {
    it('toTitleNatural should clean titles correctly', () => {
        expect(toTitleNatural('The Movie (2024) [Remastered] 1080p')).toBe('The Movie');
        expect(toTitleNatural('Sita Ramam (2022) [Multi-Sub] 2160p HDR10+ DV')).toBe('Sita Ramam');
        expect(toTitleNatural('Fight Club : Director\'s Cut')).toBe('Fight Club');
    });

    it('parseReleaseInfo should extract tech specs', () => {
        const info = parseReleaseInfo('Inception 2010 2160p BluRay x265 HDR10 Atmos-HighCode');
        expect(info.resolution).toBe('2160P');
        expect(info.source).toBe('BLURAY');
        expect(info.codec).toBe('HEVC x265');
        expect(info.hdr).toBe('HDR10');
    });
});
