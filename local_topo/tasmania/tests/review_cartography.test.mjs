import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import test from 'node:test';

import {
  parseArgs,
  resolveStyleReview,
  runReview,
} from '../scripts/review_cartography.mjs';

const pngFixture = Buffer.from('89504E470D0A1A0A', 'hex');

test('parseArgs reads review style id from CLI flag', () => {
  assert.deepEqual(parseArgs(['--style-id=tasmania-maptiler-topo']), {
    styleId: 'tasmania-maptiler-topo',
  });
});

test('resolveStyleReview rejects missing or unknown style ids with available choices', () => {
  const fixture = {
    styleReviews: {
      'tasmania-maptiler-topo': { variantExpectations: [], tiles: [] },
      'tasmania-maptiler-outdoor': { variantExpectations: [], tiles: [] },
    },
  };

  assert.throws(
    () => resolveStyleReview(fixture, ''),
    /Unknown or missing review style id: <empty>.*tasmania-maptiler-outdoor, tasmania-maptiler-topo/s,
  );
});

test('runReview writes captures under a variant-scoped output directory', async () => {
  const outputRoot = await mkdtemp(join(tmpdir(), 'peak-bagger-cartography-review-'));
  const fixture = {
    styleReviews: {
      'tasmania-maptiler-topo': {
        variantExpectations: ['reads as a close visual port of MapTiler Topo'],
        tiles: [
          {
            slug: 'mid-zoom-lake-st-clair',
            z: 12,
            x: 3711,
            y: 2577,
            expectations: ['contours remain visible'],
          },
        ],
      },
    },
  };
  const messages = [];

  try {
    await runReview({
      styleId: 'tasmania-maptiler-topo',
      fixture,
      outputRoot,
      baseUrl: new URL('http://127.0.0.1:8090'),
      fetchImpl: async (url) => {
        assert.equal(
          url.toString(),
          'http://127.0.0.1:8090/tasmania/local-topo/12/3711/2577.png',
        );

        return {
          ok: true,
          status: 200,
          arrayBuffer: async () => pngFixture,
        };
      },
      log: (message) => {
        messages.push(message);
      },
    });

    const outputPath = join(
      outputRoot,
      'tasmania-maptiler-topo',
      'mid-zoom-lake-st-clair.png',
    );
    const saved = await readFile(outputPath);
    assert.deepEqual(saved, pngFixture);
    assert.equal(
      messages.some((message) => message.includes('tasmania-maptiler-topo')), 
      true,
    );
    assert.equal(
      messages.some((message) => message.includes('reads as a close visual port of MapTiler Topo')),
      true,
    );
  } finally {
    await rm(outputRoot, { force: true, recursive: true });
  }
});
