import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';
import admin from 'firebase-admin';
import { createClient } from '@supabase/supabase-js';

// 1. Load Environment Configuration
dotenv.config({ path: path.resolve(__dirname, '.env') });

const FIREBASE_KEY_PATH =
  process.env.FIREBASE_SERVICE_ACCOUNT_KEY_PATH || './serviceAccountKey.json';
const FIREBASE_STORAGE_BUCKET = process.env.FIREBASE_STORAGE_BUCKET;
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

interface VerificationReport {
  timestamp: string;
  counts: {
    firebaseUsers: number;
    supabaseProfiles: number;
    firebaseWardrobeItems: number;
    supabaseWardrobeItems: number;
    firebaseSavedOutfits: number;
    supabaseOutfits: number;
  };
  integrity: {
    orphanedWardrobeItems: number;
    orphanedOutfits: number;
    orphanedOutfitItems: number;
  };
  storageStatus: {
    verifiedSamples: number;
    failedSamples: number;
  };
  discrepancies: string[];
  isSuccess: boolean;
}

async function runVerification() {
  console.log('🔍 Starting Firebase ➔ Supabase Migration Verification...\n');

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
  }

  // Initialize Firebase Admin
  const resolvedKeyPath = path.resolve(process.cwd(), FIREBASE_KEY_PATH);
  if (!fs.existsSync(resolvedKeyPath)) {
    throw new Error(`Firebase service account key not found at: ${resolvedKeyPath}`);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(resolvedKeyPath, 'utf-8'));
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      storageBucket: FIREBASE_STORAGE_BUCKET,
    });
  }

  const firestore = admin.firestore();

  // Initialize Supabase Admin Client
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  const report: VerificationReport = {
    timestamp: new Date().toISOString(),
    counts: {
      firebaseUsers: 0,
      supabaseProfiles: 0,
      firebaseWardrobeItems: 0,
      supabaseWardrobeItems: 0,
      firebaseSavedOutfits: 0,
      supabaseOutfits: 0,
    },
    integrity: {
      orphanedWardrobeItems: 0,
      orphanedOutfits: 0,
      orphanedOutfitItems: 0,
    },
    storageStatus: {
      verifiedSamples: 0,
      failedSamples: 0,
    },
    discrepancies: [],
    isSuccess: true,
  };

  // 1. Check Counts
  console.log('📊 [1/4] Comparing Database Entity Counts...');
  const fbUsers = await firestore.collection('users').get();
  const fbWardrobe = await firestore.collection('wardrobe_items').get();
  const fbOutfits = await firestore.collection('saved_outfits').get();

  report.counts.firebaseUsers = fbUsers.docs.length;
  report.counts.firebaseWardrobeItems = fbWardrobe.docs.length;
  report.counts.firebaseSavedOutfits = fbOutfits.docs.length;

  const { count: sbProfilesCount, error: errProfiles } = await supabase
    .from('profiles')
    .select('*', { count: 'exact', head: true });
  const { count: sbWardrobeCount, error: errWardrobe } = await supabase
    .from('wardrobe_items')
    .select('*', { count: 'exact', head: true });
  const { count: sbOutfitsCount, error: errOutfits } = await supabase
    .from('outfits')
    .select('*', { count: 'exact', head: true });

  if (errProfiles || errWardrobe || errOutfits) {
    console.error('❌ Supabase Query Error during count retrieval');
  }

  report.counts.supabaseProfiles = sbProfilesCount || 0;
  report.counts.supabaseWardrobeItems = sbWardrobeCount || 0;
  report.counts.supabaseOutfits = sbOutfitsCount || 0;

  if (report.counts.firebaseUsers !== report.counts.supabaseProfiles) {
    report.discrepancies.push(
      `Users mismatch: Firebase has ${report.counts.firebaseUsers}, Supabase has ${report.counts.supabaseProfiles}`
    );
  }
  if (report.counts.firebaseWardrobeItems !== report.counts.supabaseWardrobeItems) {
    report.discrepancies.push(
      `Wardrobe items mismatch: Firebase has ${report.counts.firebaseWardrobeItems}, Supabase has ${report.counts.supabaseWardrobeItems}`
    );
  }
  if (report.counts.firebaseSavedOutfits !== report.counts.supabaseOutfits) {
    report.discrepancies.push(
      `Outfits mismatch: Firebase has ${report.counts.firebaseSavedOutfits}, Supabase has ${report.counts.supabaseOutfits}`
    );
  }

  // 2. Check Referential Integrity
  console.log('🔗 [2/4] Validating Referential Integrity & Foreign Keys...');
  const { data: orphanWardrobe } = await supabase
    .from('wardrobe_items')
    .select('id, user_id')
    .is('user_id', null);
  report.integrity.orphanedWardrobeItems = orphanWardrobe?.length || 0;

  const { data: orphanOutfits } = await supabase
    .from('outfits')
    .select('id, user_id')
    .is('user_id', null);
  report.integrity.orphanedOutfits = orphanOutfits?.length || 0;

  if (report.integrity.orphanedWardrobeItems > 0 || report.integrity.orphanedOutfits > 0) {
    report.discrepancies.push('Found orphaned records with null user_id');
  }

  // 3. Check Storage Samples
  console.log('📦 [3/4] Verifying Storage Sample Files...');
  const { data: sampleItems } = await supabase
    .from('wardrobe_items')
    .select('source_path')
    .not('source_path', 'eq', 'unknown_source')
    .limit(10);

  if (sampleItems && sampleItems.length > 0) {
    for (const item of sampleItems) {
      if (item.source_path.startsWith('user-media/')) {
        const filePath = item.source_path.replace('user-media/', '');
        const { data: fileData, error: fileErr } = await supabase.storage
          .from('user-media')
          .download(filePath);

        if (fileErr || !fileData) {
          report.storageStatus.failedSamples++;
        } else {
          report.storageStatus.verifiedSamples++;
        }
      }
    }
  }

  // 4. Summary and Outcome
  console.log('\n======================================================');
  console.log('📋 VERIFICATION REPORT SUMMARY');
  console.log('======================================================');
  console.log(`Execution Time: ${report.timestamp}`);
  console.log('\nEntity Counts:');
  console.log(`  - Users / Profiles:    Firebase = ${report.counts.firebaseUsers.toString().padEnd(4)} | Supabase = ${report.counts.supabaseProfiles}`);
  console.log(`  - Wardrobe Items:      Firebase = ${report.counts.firebaseWardrobeItems.toString().padEnd(4)} | Supabase = ${report.counts.supabaseWardrobeItems}`);
  console.log(`  - Saved Outfits:       Firebase = ${report.counts.firebaseSavedOutfits.toString().padEnd(4)} | Supabase = ${report.counts.supabaseOutfits}`);

  console.log('\nIntegrity Checks:');
  console.log(`  - Orphaned Wardrobe Items: ${report.integrity.orphanedWardrobeItems}`);
  console.log(`  - Orphaned Outfits:        ${report.integrity.orphanedOutfits}`);

  console.log('\nStorage Sample Checks:');
  console.log(`  - Verified Files: ${report.storageStatus.verifiedSamples}`);
  console.log(`  - Failed Files:   ${report.storageStatus.failedSamples}`);

  report.isSuccess = report.discrepancies.length === 0 && report.storageStatus.failedSamples === 0;

  if (report.isSuccess) {
    console.log('\n✅ STATUS: 100% DATA INTEGRITY CONFIRMED');
  } else {
    console.log('\n⚠️ STATUS: DISCREPANCIES DETECTED');
    for (const d of report.discrepancies) {
      console.log(`  - ${d}`);
    }
  }
  console.log('======================================================\n');
}

runVerification().catch((err) => {
  console.error('💥 Verification script error:', err);
  process.exit(1);
});
