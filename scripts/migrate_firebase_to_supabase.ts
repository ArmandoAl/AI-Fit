import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import * as dotenv from 'dotenv';
import admin from 'firebase-admin';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

// 1. Load Environment Configuration
dotenv.config({ path: path.resolve(__dirname, '.env') });

const FIREBASE_KEY_PATH =
  process.env.FIREBASE_SERVICE_ACCOUNT_KEY_PATH || './serviceAccountKey.json';
const FIREBASE_STORAGE_BUCKET = process.env.FIREBASE_STORAGE_BUCKET;
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const CHECKPOINT_PATH =
  process.env.MIGRATION_CHECKPOINT_FILE ||
  path.resolve(__dirname, '.migration_checkpoint.json');

interface MigrationCheckpoint {
  migratedUsers: Record<string, string>; // firebaseUid -> supabaseUuid
  migratedWardrobeItems: Record<string, string>; // firestoreId -> supabaseUuid
  migratedOutfits: Record<string, string>; // firestoreId -> supabaseUuid
  migratedStorageFiles: Record<string, string>; // originalUrl/path -> supabaseStoragePath
  stats: {
    users: number;
    wardrobeItems: number;
    outfits: number;
    photos: number;
    storageFiles: number;
    errors: number;
  };
  lastUpdated: string;
}

// 2. Initialize Checkpoint Management
function loadCheckpoint(): MigrationCheckpoint {
  if (fs.existsSync(CHECKPOINT_PATH)) {
    try {
      const data = fs.readFileSync(CHECKPOINT_PATH, 'utf-8');
      return JSON.parse(data) as MigrationCheckpoint;
    } catch (e) {
      console.warn('⚠️ Could not parse existing checkpoint file, starting fresh.');
    }
  }
  return {
    migratedUsers: {},
    migratedWardrobeItems: {},
    migratedOutfits: {},
    migratedStorageFiles: {},
    stats: {
      users: 0,
      wardrobeItems: 0,
      outfits: 0,
      photos: 0,
      storageFiles: 0,
      errors: 0,
    },
    lastUpdated: new Date().toISOString(),
  };
}

function saveCheckpoint(checkpoint: MigrationCheckpoint) {
  checkpoint.lastUpdated = new Date().toISOString();
  fs.writeFileSync(CHECKPOINT_PATH, JSON.stringify(checkpoint, null, 2), 'utf-8');
}

// 3. Helper Functions
function computeSha256(buffer: Buffer): string {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function normalizeCategory(raw: string | undefined): 'top' | 'bottom' | 'shoes' | 'outerwear' {
  const s = (raw || '').toLowerCase().trim();
  if (s.includes('top') || s.includes('shirt') || s.includes('t-shirt') || s.includes('camisa') || s.includes('blusa') || s.includes('polo')) {
    return 'top';
  }
  if (s.includes('bottom') || s.includes('pant') || s.includes('jean') || s.includes('short') || s.includes('falda') || s.includes('trouser')) {
    return 'bottom';
  }
  if (s.includes('shoe') || s.includes('zapato') || s.includes('tenis') || s.includes('sneaker') || s.includes('boot') || s.includes('bota')) {
    return 'shoes';
  }
  if (s.includes('outer') || s.includes('jacket') || s.includes('coat') || s.includes('chaqueta') || s.includes('abrigo') || s.includes('hoodie')) {
    return 'outerwear';
  }
  return 'top'; // Safe default
}

async function downloadBuffer(urlOrPath: string, firebaseBucket: admin.storage.Storage): Promise<{ buffer: Buffer; mimeType: string } | null> {
  try {
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      const res = await fetch(urlOrPath);
      if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
      const arrayBuffer = await res.arrayBuffer();
      const mimeType = res.headers.get('content-type') || 'image/jpeg';
      return { buffer: Buffer.from(arrayBuffer), mimeType };
    } else {
      const file = firebaseBucket.bucket().file(urlOrPath);
      const [buffer] = await file.download();
      const [metadata] = await file.getMetadata();
      const mimeType = metadata.contentType || 'image/jpeg';
      return { buffer, mimeType };
    }
  } catch (e) {
    console.error(`❌ Failed to download file from ${urlOrPath}:`, e);
    return null;
  }
}

// 4. Main Migration Engine
async function runMigration() {
  console.log('🚀 Starting Firebase to Supabase Migration (AI-Fit)...');

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
  }

  // A. Initialize Firebase Admin
  const resolvedKeyPath = path.resolve(process.cwd(), FIREBASE_KEY_PATH);
  if (!fs.existsSync(resolvedKeyPath)) {
    throw new Error(`Firebase service account key not found at: ${resolvedKeyPath}`);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(resolvedKeyPath, 'utf-8'));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: FIREBASE_STORAGE_BUCKET,
  });

  const firestore = admin.firestore();
  const firebaseStorage = admin.storage();

  // B. Initialize Supabase Admin Client (Service Role)
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  const checkpoint = loadCheckpoint();

  // ============================================================================
  // STEP 1: MIGRATE USERS & PROFILES
  // ============================================================================
  console.log('\n--- Step 1: Migrating Users & Profiles ---');
  const usersSnapshot = await firestore.collection('users').get();
  console.log(`Found ${usersSnapshot.docs.length} users in Firestore.`);

  for (const doc of usersSnapshot.docs) {
    const firebaseUid = doc.id;
    const userData = doc.data();

    let supabaseUserId = checkpoint.migratedUsers[firebaseUid];

    if (!supabaseUserId) {
      // Find existing or create user in Supabase Auth
      const email = userData.email || `legacy_${firebaseUid.slice(0, 12)}@migration.aifit.app`;
      const { data: userList } = await supabase.auth.admin.listUsers();
      const existingUser = userList?.users?.find(
        (u) => u.email === email || u.user_metadata?.legacy_firebase_uid === firebaseUid
      );

      if (existingUser) {
        supabaseUserId = existingUser.id;
      } else {
        const { data: newUser, error: createErr } = await supabase.auth.admin.createUser({
          email,
          email_confirm: true,
          user_metadata: {
            legacy_firebase_uid: firebaseUid,
            display_name: userData.displayName || userData.name || '',
          },
        });

        if (createErr || !newUser.user) {
          console.error(`❌ Failed to create auth user for ${firebaseUid}:`, createErr);
          checkpoint.stats.errors++;
          continue;
        }
        supabaseUserId = newUser.user.id;
      }

      checkpoint.migratedUsers[firebaseUid] = supabaseUserId;
    }

    // Upsert into public.profiles
    const profilePayload = {
      id: supabaseUserId,
      legacy_firebase_uid: firebaseUid,
      display_name: userData.displayName || userData.name || '',
      avatar_path: userData.avatarUrl || null,
      preferences: userData.preferences || {},
      onboarding_completed: Boolean(userData.onboardingCompleted ?? false),
      identity_profile: userData.identityProfile || null,
      identity_version: userData.identityVersion || 1,
      identity_collage_path: userData.identityCollageUrl || null,
      base_image_path: userData.baseImageUrl || null,
      updated_at: new Date().toISOString(),
    };

    const { error: profileErr } = await supabase.from('profiles').upsert(profilePayload, {
      onConflict: 'id',
    });

    if (profileErr) {
      console.error(`❌ Failed to upsert profile for user ${supabaseUserId}:`, profileErr);
      checkpoint.stats.errors++;
    } else {
      checkpoint.stats.users++;
      console.log(`👤 Migrated profile for user ${firebaseUid} -> ${supabaseUserId}`);
    }

    saveCheckpoint(checkpoint);
  }

  // ============================================================================
  // STEP 2: MIGRATE WARDROBE ITEMS & STORAGE
  // ============================================================================
  console.log('\n--- Step 2: Migrating Wardrobe Items & Media ---');
  const wardrobeSnapshot = await firestore.collection('wardrobe_items').get();
  console.log(`Found ${wardrobeSnapshot.docs.length} wardrobe items in Firestore.`);

  for (const doc of wardrobeSnapshot.docs) {
    const firestoreId = doc.id;
    const itemData = doc.data();
    const firebaseUserId = itemData.userId;

    if (!firebaseUserId || !checkpoint.migratedUsers[firebaseUserId]) {
      console.warn(`⚠️ Skipping item ${firestoreId}: owner ${firebaseUserId} not found in migrated users.`);
      continue;
    }

    const supabaseUserId = checkpoint.migratedUsers[firebaseUserId];
    let supabaseItemId = checkpoint.migratedWardrobeItems[firestoreId];

    if (!supabaseItemId) {
      supabaseItemId = crypto.randomUUID();
      checkpoint.migratedWardrobeItems[firestoreId] = supabaseItemId;
    }

    let sourceStoragePath = checkpoint.migratedStorageFiles[itemData.imageUrl];
    let contentHash = 'no_image_hash';

    if (itemData.imageUrl && !sourceStoragePath) {
      const dl = await downloadBuffer(itemData.imageUrl, firebaseStorage);
      if (dl) {
        contentHash = computeSha256(dl.buffer);
        const ext = dl.mimeType.includes('png') ? 'png' : dl.mimeType.includes('webp') ? 'webp' : 'jpg';
        sourceStoragePath = `user-media/${supabaseUserId}/wardrobe/${supabaseItemId}/source.${ext}`;

        const { error: uploadErr } = await supabase.storage
          .from('user-media')
          .upload(`${supabaseUserId}/wardrobe/${supabaseItemId}/source.${ext}`, dl.buffer, {
            contentType: dl.mimeType,
            upsert: true,
          });

        if (uploadErr) {
          console.error(`❌ Storage upload error for item ${firestoreId}:`, uploadErr);
          checkpoint.stats.errors++;
        } else {
          checkpoint.migratedStorageFiles[itemData.imageUrl] = sourceStoragePath;
          checkpoint.stats.storageFiles++;
        }
      }
    }

    const category = normalizeCategory(itemData.type || itemData.category);
    const wardrobePayload = {
      id: supabaseItemId,
      user_id: supabaseUserId,
      legacy_firestore_id: firestoreId,
      name: itemData.name || itemData.subType || 'Prenda',
      category: category,
      subtype: itemData.subType || itemData.name || 'item',
      brand: itemData.brand || null,
      source_path: sourceStoragePath || itemData.imageUrl || 'unknown_source',
      content_hash: contentHash,
      colors: Array.isArray(itemData.colors) ? itemData.colors : (itemData.color ? [String(itemData.color)] : []),
      style_tags: Array.isArray(itemData.styleTags) ? itemData.styleTags : [],
      seasons: Array.isArray(itemData.season) ? itemData.season : (Array.isArray(itemData.seasons) ? itemData.seasons : []),
      ai_metadata: itemData.aiMetadata || itemData.metadata || {},
      processing_status: 'ready',
      created_at: itemData.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const { error: itemErr } = await supabase.from('wardrobe_items').upsert(wardrobePayload, {
      onConflict: 'user_id, legacy_firestore_id',
    });

    if (itemErr) {
      console.error(`❌ Failed to upsert wardrobe item ${firestoreId}:`, itemErr);
      checkpoint.stats.errors++;
    } else {
      checkpoint.stats.wardrobeItems++;
    }

    saveCheckpoint(checkpoint);
  }

  // ============================================================================
  // STEP 3: MIGRATE SAVED OUTFITS & OUTFIT ITEMS
  // ============================================================================
  console.log('\n--- Step 3: Migrating Saved Outfits & Relations ---');
  const outfitsSnapshot = await firestore.collection('saved_outfits').get();
  console.log(`Found ${outfitsSnapshot.docs.length} saved outfits in Firestore.`);

  for (const doc of outfitsSnapshot.docs) {
    const firestoreId = doc.id;
    const outfitData = doc.data();
    const firebaseUserId = outfitData.userId;

    if (!firebaseUserId || !checkpoint.migratedUsers[firebaseUserId]) {
      console.warn(`⚠️ Skipping outfit ${firestoreId}: owner ${firebaseUserId} not found.`);
      continue;
    }

    const supabaseUserId = checkpoint.migratedUsers[firebaseUserId];
    let supabaseOutfitId = checkpoint.migratedOutfits[firestoreId];

    if (!supabaseOutfitId) {
      supabaseOutfitId = crypto.randomUUID();
      checkpoint.migratedOutfits[firestoreId] = supabaseOutfitId;
    }

    // 1. Create a parent outfit_generation record
    const generationId = crypto.randomUUID();
    const idempotencyKey = `migration_gen_${firestoreId}`;

    const generationPayload = {
      id: generationId,
      user_id: supabaseUserId,
      idempotency_key: idempotencyKey,
      user_prompt: outfitData.userPrompt || 'Generated look',
      intent: outfitData.intent || {},
      status: 'completed',
      text_provider: 'firebase_gemini',
      text_model: 'gemini-2.5-flash',
      created_at: outfitData.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    };

    await supabase.from('outfit_generations').upsert(generationPayload, {
      onConflict: 'user_id, idempotency_key',
    });

    // 2. Transfer Try-On Image if exists
    let tryOnStoragePath: string | null = null;
    if (outfitData.tryOnImageUrl) {
      const cached = checkpoint.migratedStorageFiles[outfitData.tryOnImageUrl];
      if (cached) {
        tryOnStoragePath = cached;
      } else {
        const dl = await downloadBuffer(outfitData.tryOnImageUrl, firebaseStorage);
        if (dl) {
          const ext = dl.mimeType.includes('webp') ? 'webp' : 'jpg';
          tryOnStoragePath = `generated/${supabaseUserId}/tryons/${supabaseOutfitId}/source.${ext}`;
          await supabase.storage
            .from('generated')
            .upload(`${supabaseUserId}/tryons/${supabaseOutfitId}/source.${ext}`, dl.buffer, {
              contentType: dl.mimeType,
              upsert: true,
            });
          checkpoint.migratedStorageFiles[outfitData.tryOnImageUrl] = tryOnStoragePath;
          checkpoint.stats.storageFiles++;
        }
      }
    }

    // 3. Upsert Outfit record
    const outfitPayload = {
      id: supabaseOutfitId,
      generation_id: generationId,
      user_id: supabaseUserId,
      rank: 1,
      match_percentage: Math.min(100, Math.max(0, Number(outfitData.matchPercentage) || 90)),
      compatibility_score: Number(outfitData.compatibilityScore) || 0.9,
      explanation: outfitData.outfit?.explanation || 'Migrated outfit',
      explanation_es: outfitData.outfit?.explanationEs || 'Look migrado desde Firebase',
      try_on_path: tryOnStoragePath,
      is_favorite: Boolean(outfitData.isFavorite ?? false),
      custom_tags: Array.isArray(outfitData.customTags) ? outfitData.customTags : [],
      notes: outfitData.notes || null,
      view_count: Number(outfitData.viewCount) || 0,
      created_at: outfitData.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    };

    const { error: outfitErr } = await supabase.from('outfits').upsert(outfitPayload, {
      onConflict: 'id',
    });

    if (outfitErr) {
      console.error(`❌ Failed to upsert outfit ${firestoreId}:`, outfitErr);
      checkpoint.stats.errors++;
    } else {
      checkpoint.stats.outfits++;

      // 4. Create Junction M:N Items in public.outfit_items
      const outfitInner = outfitData.outfit || {};
      const roles: Array<{ role: 'top' | 'bottom' | 'shoes' | 'outerwear'; rawId?: string }> = [
        { role: 'top', rawId: outfitInner.topId },
        { role: 'bottom', rawId: outfitInner.bottomId },
        { role: 'shoes', rawId: outfitInner.shoesId },
        { role: 'outerwear', rawId: outfitInner.outerwearId },
      ];

      for (const { role, rawId } of roles) {
        if (!rawId) continue;
        const supabaseWardrobeItemId = checkpoint.migratedWardrobeItems[rawId];
        if (!supabaseWardrobeItemId) continue;

        await supabase.from('outfit_items').upsert({
          outfit_id: supabaseOutfitId,
          wardrobe_item_id: supabaseWardrobeItemId,
          role,
        }, {
          onConflict: 'outfit_id, role',
        });
      }
    }

    saveCheckpoint(checkpoint);
  }

  console.log('\n======================================================');
  console.log('🎉 Migration Completed Successfully!');
  console.log('📊 Summary Statistics:');
  console.log(`   - Users Migrated:          ${checkpoint.stats.users}`);
  console.log(`   - Wardrobe Items Migrated: ${checkpoint.stats.wardrobeItems}`);
  console.log(`   - Outfits Migrated:        ${checkpoint.stats.outfits}`);
  console.log(`   - Storage Files Copied:    ${checkpoint.stats.storageFiles}`);
  console.log(`   - Total Errors Encountered: ${checkpoint.stats.errors}`);
  console.log(`📄 Checkpoint saved at: ${CHECKPOINT_PATH}`);
  console.log('======================================================\n');
}

runMigration().catch((err) => {
  console.error('💥 Fatal error running migration:', err);
  process.exit(1);
});
