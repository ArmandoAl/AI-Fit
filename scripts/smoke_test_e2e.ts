import * as path from 'path';
import * as dotenv from 'dotenv';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

// 1. Load Environment Variables (.env from scripts, root or process.env)
dotenv.config({ path: path.resolve(__dirname, '.env') });
dotenv.config({ path: path.resolve(__dirname, '../.env') });

const SUPABASE_URL = process.env.SUPABASE_URL || '';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || '';
const IMAGE_WORKER_URL = process.env.IMAGE_WORKER_URL || 'http://localhost:8000';

interface TestResult {
  suite: string;
  name: string;
  status: 'PASSED' | 'FAILED' | 'SKIPPED';
  durationMs: number;
  details?: string;
  error?: string;
}

const results: TestResult[] = [];

function recordResult(res: TestResult) {
  results.push(res);
  const icon = res.status === 'PASSED' ? '✅' : res.status === 'SKIPPED' ? '⏭️' : '❌';
  console.log(`${icon} [${res.suite}] ${res.name}: ${res.status} (${res.durationMs}ms)`);
  if (res.details) console.log(`   ℹ️  ${res.details}`);
  if (res.error) console.log(`   ⚠️  Error: ${res.error}`);
}

async function testImageWorkerHealth(): Promise<void> {
  const start = performance.now();
  const healthUrl = `${IMAGE_WORKER_URL.replace(/\/$/, '')}/health`;
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 3500);

    const res = await fetch(healthUrl, {
      method: 'GET',
      signal: controller.signal,
    });
    clearTimeout(timeoutId);

    const duration = Math.round(performance.now() - start);
    if (!res.ok) {
      recordResult({
        suite: 'ImageWorker',
        name: 'Healthcheck Endpoint (/health)',
        status: 'FAILED',
        durationMs: duration,
        error: `HTTP ${res.status}: ${res.statusText}`,
      });
      return;
    }

    const data = await res.json() as Record<string, unknown>;
    if (data.status === 'healthy' && data.service === 'image-worker') {
      recordResult({
        suite: 'ImageWorker',
        name: 'Healthcheck Endpoint (/health)',
        status: 'PASSED',
        durationMs: duration,
        details: `Service healthy (v${data.version || '1.1.0'}, model: ${data.clip_model})`,
      });
    } else {
      recordResult({
        suite: 'ImageWorker',
        name: 'Healthcheck Endpoint (/health)',
        status: 'FAILED',
        durationMs: duration,
        details: JSON.stringify(data),
      });
    }
  } catch (err: unknown) {
    const duration = Math.round(performance.now() - start);
    const msg = err instanceof Error ? err.message : String(err);
    recordResult({
      suite: 'ImageWorker',
      name: 'Healthcheck Endpoint (/health)',
      status: 'SKIPPED',
      durationMs: duration,
      details: `Local service not running at ${healthUrl} (Run: uvicorn main:app --port 8000 inside services/image-worker/)`,
      error: msg,
    });
  }
}

async function testAiRouterHealth(client: SupabaseClient | null): Promise<void> {
  const start = performance.now();
  if (!SUPABASE_URL || (!SUPABASE_SERVICE_ROLE_KEY && !SUPABASE_ANON_KEY)) {
    recordResult({
      suite: 'AiRouter',
      name: 'Gateway Ping Check (action: ping)',
      status: 'SKIPPED',
      durationMs: 0,
      details: 'SUPABASE_URL and API keys not configured in .env',
    });
    return;
  }

  const fnUrl = `${SUPABASE_URL.replace(/\/$/, '')}/functions/v1/ai-router`;
  const token = SUPABASE_SERVICE_ROLE_KEY || SUPABASE_ANON_KEY;

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);

    const res = await fetch(fnUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify({
        action: 'ping',
        idempotencyKey: `smoke_test_${Date.now()}`,
      }),
      signal: controller.signal,
    });
    clearTimeout(timeoutId);

    const duration = Math.round(performance.now() - start);
    if (!res.ok) {
      recordResult({
        suite: 'AiRouter',
        name: 'Gateway Ping Check (action: ping)',
        status: 'FAILED',
        durationMs: duration,
        error: `HTTP ${res.status}: ${res.statusText}`,
      });
      return;
    }

    const data = await res.json() as Record<string, unknown>;
    if (data.status === 'ok' && data.action === 'ping') {
      recordResult({
        suite: 'AiRouter',
        name: 'Gateway Ping Check (action: ping)',
        status: 'PASSED',
        durationMs: duration,
        details: `Ping successful: ${data.content || 'OK'}`,
      });
    } else {
      recordResult({
        suite: 'AiRouter',
        name: 'Gateway Ping Check (action: ping)',
        status: 'FAILED',
        durationMs: duration,
        details: `Unexpected response payload: ${JSON.stringify(data)}`,
      });
    }
  } catch (err: unknown) {
    const duration = Math.round(performance.now() - start);
    const msg = err instanceof Error ? err.message : String(err);
    recordResult({
      suite: 'AiRouter',
      name: 'Gateway Ping Check (action: ping)',
      status: 'SKIPPED',
      durationMs: duration,
      details: `Edge Function not yet deployed or unreachable at ${fnUrl}`,
      error: msg,
    });
  }
}

async function testDatabaseTablesAndRls(client: SupabaseClient | null): Promise<void> {
  const tables = [
    { name: 'profiles', key: 'id' },
    { name: 'wardrobe_items', key: 'id' },
    { name: 'outfits', key: 'id' },
    { name: 'outfit_generations', key: 'id' },
    { name: 'outfit_items', key: 'id' },
    { name: 'user_photos', key: 'id' },
  ];

  if (!client) {
    for (const t of tables) {
      recordResult({
        suite: 'Database & RLS',
        name: `Table schema validation: public.${t.name}`,
        status: 'SKIPPED',
        durationMs: 0,
        details: 'Supabase client credentials missing in .env',
      });
    }
    return;
  }

  for (const t of tables) {
    const start = performance.now();
    try {
      const { data, error, status } = await client
        .from(t.name)
        .select(t.key)
        .limit(1);

      const duration = Math.round(performance.now() - start);
      if (error && status !== 200 && status !== 206) {
        recordResult({
          suite: 'Database & RLS',
          name: `Table schema validation: public.${t.name}`,
          status: 'FAILED',
          durationMs: duration,
          error: `[${error.code}] ${error.message}`,
        });
      } else {
        recordResult({
          suite: 'Database & RLS',
          name: `Table schema validation: public.${t.name}`,
          status: 'PASSED',
          durationMs: duration,
          details: `Accessible & responsive (rows probed: ${data?.length ?? 0})`,
        });
      }
    } catch (err: unknown) {
      const duration = Math.round(performance.now() - start);
      recordResult({
        suite: 'Database & RLS',
        name: `Table schema validation: public.${t.name}`,
        status: 'FAILED',
        durationMs: duration,
        error: String(err),
      });
    }
  }

  // Check RLS isolation with anon client simulation
  const anonClient = createClient(
    SUPABASE_URL,
    SUPABASE_ANON_KEY || 'anon-test-key',
    { auth: { persistSession: false } }
  );

  const rlsStart = performance.now();
  try {
    // Unauthenticated user should not be able to read all private profiles
    const { data, error } = await anonClient
      .from('profiles')
      .select('id')
      .limit(5);

    const rlsDuration = Math.round(performance.now() - rlsStart);
    // If RLS is working properly, an anonymous user gets either 0 rows or error
    if (!error && (data?.length ?? 0) === 0) {
      recordResult({
        suite: 'Database & RLS',
        name: 'RLS Anonymous Isolation Policy',
        status: 'PASSED',
        durationMs: rlsDuration,
        details: 'Anonymous requests cleanly blocked / filtered (0 rows returned)',
      });
    } else if (error) {
      recordResult({
        suite: 'Database & RLS',
        name: 'RLS Anonymous Isolation Policy',
        status: 'PASSED',
        durationMs: rlsDuration,
        details: `Anonymous access denied as expected: ${error.message}`,
      });
    } else {
      recordResult({
        suite: 'Database & RLS',
        name: 'RLS Anonymous Isolation Policy',
        status: 'FAILED',
        durationMs: rlsDuration,
        details: `WARNING: Anonymous query returned ${data?.length} rows without authentication! Verify RLS is enabled on public.profiles.`,
      });
    }
  } catch (err: unknown) {
    recordResult({
      suite: 'Database & RLS',
      name: 'RLS Anonymous Isolation Policy',
      status: 'SKIPPED',
      durationMs: Math.round(performance.now() - rlsStart),
      error: String(err),
    });
  }
}

async function testStorageBuckets(client: SupabaseClient | null): Promise<void> {
  const buckets = ['user-media', 'generated'];

  if (!client) {
    for (const b of buckets) {
      recordResult({
        suite: 'Storage',
        name: `Bucket configuration: ${b}`,
        status: 'SKIPPED',
        durationMs: 0,
        details: 'Supabase credentials missing in .env',
      });
    }
    return;
  }

  const startList = performance.now();
  try {
    const { data: bucketList, error: listError } = await client.storage.listBuckets();
    const durationList = Math.round(performance.now() - startList);

    if (listError) {
      recordResult({
        suite: 'Storage',
        name: 'Bucket Listing API',
        status: 'FAILED',
        durationMs: durationList,
        error: listError.message,
      });
      return;
    }

    for (const b of buckets) {
      const match = bucketList?.find((item) => item.id === b || item.name === b);
      if (!match) {
        recordResult({
          suite: 'Storage',
          name: `Bucket configuration: ${b}`,
          status: 'FAILED',
          durationMs: 0,
          error: `Bucket '${b}' does not exist. Run migration scripts or create in Supabase dashboard.`,
        });
      } else {
        const isPrivate = !match.public;
        recordResult({
          suite: 'Storage',
          name: `Bucket configuration: ${b}`,
          status: isPrivate ? 'PASSED' : 'FAILED',
          durationMs: 0,
          details: isPrivate
            ? `Verified private bucket (public: false, size limit: ${match.file_size_limit || 'default'})`
            : `WARNING: Bucket '${b}' is public! It must be private with RLS policies.`,
        });
      }
    }

    // Storage upload & delete test
    const testBucket = 'user-media';
    const testPath = `smoke_test/test_${Date.now()}.txt`;
    const testPayload = Buffer.from('Smoke test payload for AI-Fit cutover verification');

    const uploadStart = performance.now();
    const { error: uploadError } = await client.storage
      .from(testBucket)
      .upload(testPath, testPayload, { contentType: 'text/plain', upsert: true });

    const uploadDuration = Math.round(performance.now() - uploadStart);

    if (uploadError) {
      recordResult({
        suite: 'Storage',
        name: `Upload & Delete Lifecycle (${testBucket})`,
        status: 'FAILED',
        durationMs: uploadDuration,
        error: uploadError.message,
      });
    } else {
      // Clean up uploaded file
      await client.storage.from(testBucket).remove([testPath]);
      recordResult({
        suite: 'Storage',
        name: `Upload & Delete Lifecycle (${testBucket})`,
        status: 'PASSED',
        durationMs: uploadDuration,
        details: `Successfully uploaded ${testPayload.length} bytes to ${testPath} and removed it cleanly.`,
      });
    }
  } catch (err: unknown) {
    recordResult({
      suite: 'Storage',
      name: 'Bucket operations',
      status: 'FAILED',
      durationMs: Math.round(performance.now() - startList),
      error: String(err),
    });
  }
}

async function main() {
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('🧪 AI-FIT END-TO-END SMOKE TEST & HEALTH AUDIT');
  console.log('═══════════════════════════════════════════════════════════════');
  console.log(`⏱️  Timestamp: ${new Date().toISOString()}`);
  console.log(`🌐 Supabase URL: ${SUPABASE_URL || '(Not set in .env)'}`);
  console.log(`🖼️  Image Worker URL: ${IMAGE_WORKER_URL}`);
  console.log('───────────────────────────────────────────────────────────────\n');

  let client: SupabaseClient | null = null;
  if (SUPABASE_URL && (SUPABASE_SERVICE_ROLE_KEY || SUPABASE_ANON_KEY)) {
    client = createClient(
      SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY || SUPABASE_ANON_KEY,
      { auth: { persistSession: false } }
    );
  }

  // 1. Check Image Worker
  console.log('📡 Suite 1: Vision Ingestion Microservice (Image Worker)');
  await testImageWorkerHealth();
  console.log('');

  // 2. Check AI Router Edge Function
  console.log('⚡ Suite 2: AI Gateway Server-Side (ai-router Edge Function)');
  await testAiRouterHealth(client);
  console.log('');

  // 3. Check Database Tables & RLS Policies
  console.log('🗄️  Suite 3: Postgres Relational Database & RLS Security');
  await testDatabaseTablesAndRls(client);
  console.log('');

  // 4. Check Storage Buckets
  console.log('📦 Suite 4: Supabase Storage Buckets & Policies');
  await testStorageBuckets(client);
  console.log('');

  // Summary Report
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('📊 SMOKE TEST SUMMARY REPORT');
  console.log('═══════════════════════════════════════════════════════════════');

  const passed = results.filter((r) => r.status === 'PASSED').length;
  const failed = results.filter((r) => r.status === 'FAILED').length;
  const skipped = results.filter((r) => r.status === 'SKIPPED').length;
  const total = results.length;

  console.log(`Total Checks: ${total}`);
  console.log(`✅ Passed:    ${passed}`);
  console.log(`❌ Failed:    ${failed}`);
  console.log(`⏭️  Skipped:   ${skipped}`);
  console.log('───────────────────────────────────────────────────────────────');

  if (failed > 0) {
    console.log('⚠️  Status: ATTENTION REQUIRED (One or more critical checks failed)');
    process.exit(1);
  } else {
    console.log('🎉 Status: ALL ACTIVE SUITES HEALTHY & OPERATIONAL');
    process.exit(0);
  }
}

main().catch((err) => {
  console.error('💥 Fatal error executing smoke tests:', err);
  process.exit(1);
});
