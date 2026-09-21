import os
from sentence_transformers import SentenceTransformer
import rembg

print("⏳ [preload_models] Precargando modelo CLIP 'clip-ViT-B-32'...")
SentenceTransformer('clip-ViT-B-32')

print("⏳ [preload_models] Precargando modelo 'u2net' para rembg...")
rembg.new_session('u2net')

# Pre-cachear también u2net_cloth_seg si es posible para optimizar segmentación textil
try:
    print("⏳ [preload_models] Precargando modelo 'u2net_cloth_seg'...")
    rembg.new_session('u2net_cloth_seg')
except Exception as e:
    print(f"ℹ️ [preload_models] u2net_cloth_seg omitido ({e}), u2net principal disponible.")

print("✅ Modelos precargados exitosamente en la imagen.")
