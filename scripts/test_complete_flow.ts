import * as path from 'path';
import * as dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

dotenv.config({ path: path.resolve(__dirname, '.env') });

const SUPABASE_URL = process.env.SUPABASE_URL || '';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const IMAGE_WORKER_URL = process.env.IMAGE_WORKER_URL || '';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

async function runCompleteFlow() {
  console.log('🚀 ========================================================');
  console.log('👗 AI-FIT COMPLETE FLOW VALIDATION: ADD ITEM -> OUTFIT -> TRY-ON');
  console.log('🚀 ========================================================\n');

  // Step 1: Healthcheck Image Worker & AI Router
  console.log('1️⃣ Testing Image-Worker Health & CLIP Encoding...');
  const healthRes = await fetch(`${IMAGE_WORKER_URL}/health`);
  const healthData = await healthRes.json();
  console.log('   ✅ Image-Worker Health:', healthData);

  const encodeRes = await fetch(`${IMAGE_WORKER_URL}/encode-text`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text: 'black minimalist oversized blazer jacket' }),
  });
  const encodeData = await encodeRes.json();
  const vectorDim = encodeData.vector?.length || encodeData.dimensions || 0;
  console.log(`   ✅ CLIP Text Embedding generated (dimensions: ${vectorDim})`);

  // Step 2: Query a real user and real wardrobe items from DB
  console.log('\n2️⃣ Querying existing user profile and wardrobe items from DB...');
  const { data: users } = await supabase.from('profiles').select('id, full_name').limit(1);
  const testUser = (users && users.length > 0)
    ? users[0]
    : { id: '00000000-0000-0000-0000-000000000001', full_name: 'Test Persona User' };
  console.log(`   👤 Using user: ${testUser.id} (${testUser.full_name || 'Anonymous'})`);

  const { data: items, error: itemErr } = await supabase
    .from('wardrobe_items')
    .select('id, name, category, subtype, source_path, cutout_path')
    .eq('user_id', testUser.id)
    .limit(5);

  if (itemErr || !items || items.length === 0) {
    console.log('   ⚠️ No wardrobe items found for user, querying any wardrobe items...');
  }
  const { data: anyItems } = await supabase
    .from('wardrobe_items')
    .select('id, name, category, subtype, source_path, cutout_path')
    .limit(4);

  const testItems = (items && items.length > 0) ? items : (anyItems || []);
  console.log(`   👕 Found ${testItems.length} wardrobe items for testing:`);
  for (const it of testItems) {
    console.log(`      • [${it.category}] ${it.name || it.subtype || it.id} (cutout: ${it.cutout_path ? 'YES' : 'NO'})`);
  }

  // Step 3: Check User Photos (Identity for try-on)
  console.log('\n3️⃣ Checking user photos for identity preservation...');
  const { data: photos } = await supabase
    .from('user_photos')
    .select('id, photo_url, photo_type')
    .limit(2);

  let identityUrl = '';
  if (photos && photos.length > 0) {
    identityUrl = photos[0].photo_url;
    console.log(`   📸 Identity Photo found: ${photos[0].photo_type} -> ${identityUrl}`);
  } else {
    // Standard test identity image
    identityUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=80';
    console.log(`   📸 Using sample photorealistic identity reference: ${identityUrl}`);
  }

  // Step 4: Test Flat-Lay Composition via Image Worker
  console.log('\n4️⃣ Testing Flat-Lay Composition via Image-Worker (/composite-flatlay)...');
  const sampleGarments = [
    {
      category: 'tops',
      cutout_url: 'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=400&auto=format&fit=crop&q=80',
    },
    {
      category: 'bottoms',
      cutout_url: 'https://images.unsplash.com/photo-1542272604-780c96856592?w=400&auto=format&fit=crop&q=80',
    }
  ];

  let flatlayUrl = '';
  try {
    const flatlayRes = await fetch(`${IMAGE_WORKER_URL}/composite-flatlay`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        user_id: testUser.id,
        items: sampleGarments,
      }),
    });
    if (flatlayRes.ok) {
      const flatlayData = await flatlayRes.json();
      flatlayUrl = flatlayData.flatlay_url || '';
      console.log('   ✅ Flat-lay composed successfully:', flatlayUrl || 'Generated Base64/Buffer');
    } else {
      console.warn(`   ⚠️ Flatlay compositing returned HTTP ${flatlayRes.status}, falling back to garment list.`);
    }
  } catch (flErr) {
    console.warn('   ⚠️ Flatlay direct endpoint test skipped/error:', flErr);
  }

  // Step 5: Test AI-Router Outfit Suggestion / Generation
  console.log('\n5️⃣ Testing Outfit Generation via ai-router (action: chat/intent)...');
  const fnUrl = `${SUPABASE_URL.replace(/\/$/, '')}/functions/v1/ai-router`;
  const outfitGenRes = await fetch(fnUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({
      action: 'chat',
      messages: [
        {
          role: 'system',
          content: 'You are an AI fashion stylist for AI-Fit. Suggest a stylish outfit from available items.',
        },
        {
          role: 'user',
          content: 'Create a casual Friday office outfit combining a white top and denim jeans.',
        },
      ],
    }),
  });

  if (outfitGenRes.ok) {
    const genData = await outfitGenRes.json();
    console.log('   ✅ AI Stylist Response received:');
    console.log(`      "${(genData.content || '').substring(0, 150)}..."`);
  } else {
    console.warn(`   ⚠️ AI Stylist returned HTTP ${outfitGenRes.status}`);
  }

  // Step 6: Test Virtual Try-On Generation (Multimodal Gemini 2.5 Flash / Imagen via ai-router)
  console.log('\n6️⃣ Testing Virtual Try-On via ai-router (action: generate_tryon)...');
  const tryOnPrompt = `Photorealistic full-body fashion editorial photograph of the EXACT person from the identity reference image, preserving their exact facial features, skin tone, hair, and body proportions. The person is standing in a natural relaxed pose wearing the garments shown in the reference image. The garments must match the colors, textures, cut, and details of the provided garments. Neutral modern minimalist interior background, soft natural studio lighting.`;

  const tryOnPayload = {
    action: 'generate_tryon',
    prompt: tryOnPrompt,
    identityImageUrl: identityUrl,
    garmentImageUrls: [
      'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=400&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1542272604-780c96856592?w=400&auto=format&fit=crop&q=80',
    ],
    userId: testUser.id,
    outfitId: 'test-outfit-' + Date.now(),
    idempotencyKey: 'tryon_test_' + Date.now(),
  };

  const tryOnStartTime = performance.now();
  const tryOnRes = await fetch(fnUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify(tryOnPayload),
  });

  const tryOnDuration = Math.round(performance.now() - tryOnStartTime);

  if (tryOnRes.ok) {
    const tryOnData = await tryOnRes.json();
    console.log(`   ✅ Try-On generation succeeded in ${tryOnDuration}ms!`);
    console.log(`   🖼️ Result Image URL: ${tryOnData.imageUrl || tryOnData.content || 'Image generated'}`);
    console.log(`   🏷️ Provider / Model: ${tryOnData.provider || 'google-gemini'} (${tryOnData.model || 'gemini-2.5-flash'})`);
  } else {
    const errBody = await tryOnRes.text();
    console.error(`   ❌ Try-On generation failed (${tryOnRes.status}):`, errBody);
  }

  console.log('\n🎉 ========================================================');
  console.log('✅ COMPLETE FLOW TEST EXECUTION FINISHED');
  console.log('🎉 ========================================================');
}

runCompleteFlow().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
